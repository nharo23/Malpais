//
//  Wave.mm
//  malpais
//
//  Created by ole kristensen on 11/02/11.
//  Copyright 2011 Recoil Performance Group. All rights reserved.
//

#import "Wave.h"
#import "Keystoner.h"


@implementation Wave
static void BuildDeviceMenu(AudioDeviceList *devlist, NSPopUpButton *menu, AudioDeviceID initSel);


-(void) initPlugin{
	
	voiceWaveForms = [NSMutableArray arrayWithCapacity:NUM_VOICES];
	
	[voiceWaveForms retain];
	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:1.0] named:@"alphaWall"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:1.0] named:@"alphaFloor"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:10.0] named:@"lineWidth"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:1.0] named:@"random"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:1.0] named:@"amplitude"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:0 maxValue:10.0] named:@"frequency"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:-2.0 maxValue:2.0] named:@"drift"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:1.0] named:@"smoothing"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:MAX_RESOLUTION minValue:1.0 maxValue:MAX_RESOLUTION] named:@"resolution"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:10 minValue:1 maxValue:10] named:@"liveVoiceSamples"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:10 minValue:1 maxValue:100] named:@"liveVoiceAmplification"];
	[self addProperty:[BoolProperty boolPropertyWithDefaultvalue:0.0] named:@"recordLive"];
	[self addProperty:[BoolProperty boolPropertyWithDefaultvalue:0.0] named:@"updateWaveForms"];
	
	for (int iBand = 0; iBand < NUM_BANDS; iBand++) {
		PluginProperty * p = [NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:1.0];
		[self addProperty:p named:[NSString stringWithFormat:@"liveVoiceBand%i", iBand+1]];
	}
	
	NSMutableArray * aVoice = [NSMutableArray arrayWithCapacity:MAX_RESOLUTION];
	for(int i=0;i<MAX_RESOLUTION;i++){
		[aVoice addObject:[NSNumber numberWithDouble:0.0]];
	}
	[voiceWaveForms addObject:aVoice];
	
	PluginProperty * p = [NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:1.0];
	[self addProperty:p named:@"liveVoiceOffset"];
	
	for(int iVoice = 0; iVoice < NUM_VOICES; iVoice++){
		for (int iBand = 0; iBand < NUM_BANDS; iBand++) {
			PluginProperty * p = [NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:1.0];
			[self addProperty:p named:[NSString stringWithFormat:@"voice%iBand%i", iVoice+1, iBand+1]];
		}
		NSMutableArray * aVoice = [NSMutableArray arrayWithCapacity:MAX_RESOLUTION];
		
		for(int i=0;i<MAX_RESOLUTION;i++){
			[aVoice addObject:[NSNumber numberWithDouble:0.0]];
		}
		
		[voiceWaveForms addObject:aVoice];
		PluginProperty * p = [NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:1.0];
		[self addProperty:p named:[NSString stringWithFormat:@"voice%iOffset", iVoice+1]];
	}
	
	//	mInputDeviceList = new AudioDeviceList(true);
	
	liveVoice = [[WaveObject alloc] init];
	[liveVoice loadMic];
	
}

-(void) setup{
	
	//	UInt32 propsize=0;
	//	propsize = sizeof(AudioDeviceID);
	//	verify_noerr (AudioHardwareGetProperty(kAudioHardwarePropertyDefaultInputDevice, &propsize, &inputDevice));
	//	BuildDeviceMenu(mInputDeviceList, mInputDevices, inputDevice);
		
	// bind midi channels and controlnumbers
	
	int midiControlNumber;
	
	for(int iVoice = 0; iVoice < NUM_VOICES; iVoice++){
		midiControlNumber = iVoice*10;
		for (int iBand = 0; iBand < NUM_BANDS; iBand++) {
			PluginProperty * p = [properties objectForKey:[NSString stringWithFormat:@"voice%iBand%i", iVoice+1, iBand+1]];
			[p setMidiChannel:[NSNumber numberWithInt:MIDI_CHANNEL]];
			if(midiControlNumber==0){
				[p setMidiNumber:[NSNumber numberWithInt:7]]; // undtagelse der bekræfter reglen, da nummer 0 ikke kan bruges
			} else {
				[p setMidiNumber:[NSNumber numberWithInt:midiControlNumber]];
			}
			midiControlNumber++;
		}
	}
	
	for (int iVoice = 0; iVoice < NUM_VOICES+1; iVoice++) {
		for (int iBand = 0; iBand < NUM_BANDS; iBand++) {
			for (int i = 0; i < MAX_RESOLUTION; i++) {
				voiceSourceWaves[iVoice][iBand][i] = 0.0;
			}
		}
	}
	
}


-(void) update:(NSDictionary *)drawingInformation{
	
	float now = ofGetElapsedTimef();
	frameRateDeltaTime = now - lastUpdateTime;
	lastUpdateTime = now;
	
	if (PropB(@"recordLive")) {
		liveSamples = 1 << (int)PropF(@"liveVoiceSamples");
		[liveVoice updateWithSpeed:1.0/ofGetFrameRate() * liveSamples];
		liveFFT.powerSpectrum(0, (int)liveSamples/2, [liveVoice getWaveData]-liveSamples, (int)liveSamples, &magnitude[0], &phase[0], &power[0], &avg_power);
		float amplification = PropF(@"liveVoiceAmplification");
		
		int thresholds[] = {0,6,7,8,10,80,150,liveSamples/2};
		
		for (int iBand=0; iBand < NUM_BANDS; iBand++) {
			float bandMagnitude= 0;
			for (int iMagnitude = thresholds[iBand]; iMagnitude < thresholds[iBand+1]; iMagnitude++) {
				bandMagnitude += magnitude[iMagnitude];
			}
			bandMagnitude *= 1.0/(thresholds[iBand+1]-thresholds[iBand]);
			NSString * propStr = [NSString stringWithFormat:@"liveVoiceBand%i", iBand+1];
			
			bandMagnitude = (bandMagnitude/liveSamples)*amplification;
			
			[[properties objectForKey:propStr] setFloatValue:bandMagnitude];
		}
	}
	
	if(PropB(@"updateWaveForms")){
		float resolution = roundf(PropF(@"resolution"));
		
		for(int iVoice = 0; iVoice < NUM_VOICES+1; iVoice++){
			
			NSMutableArray * aVoice = [voiceWaveForms objectAtIndex:iVoice];
			
			if(resolution != [aVoice count]){
				
				[aVoice removeAllObjects];
				
				for(int i=0;i<resolution;i++){
					[aVoice addObject:[NSNumber numberWithDouble:0.0]];
				}
				
			}
			
			NSString * propStr;
			
			if(iVoice == 0)
				propStr = [NSString stringWithFormat:@"liveVoiceOffset"];
			else 
				propStr = [NSString stringWithFormat:@"voice%iOffset", iVoice];
						
			aVoice = [self getWaveFormWithIndex:iVoice 
									  amplitude:1.0 
									 driftSpeed:PropF(@"drift")
									  smoothing:PropF(@"smoothing")
									  freqeuncy:PropF(@"frequency")
										 random:PropF(@"random")
										 offset:PropF(propStr)
								withFormerArray:[voiceWaveForms objectAtIndex:iVoice]
					  ];
			
			
			[voiceWaveForms replaceObjectAtIndex:iVoice withObject:aVoice];
			
		}
		
	}
	
}


-(void) draw:(NSDictionary *)drawingInformation{
	
	float resolution = roundf(PropF(@"resolution"));
	
	ofSetColor(255, 255, 255);
	ofNoFill();
	ofSetLineWidth(PropF(@"lineWidth"));
	
	ApplySurface(@"Floor"); {
		
		if (PropF(@"alphaFloor") > 0) {
			
			ofSetColor(255, 255, 255, 255.0*PropF(@"alphaFloor"));
			
			NSMutableArray * aVoice;
			
			glTranslated(0, -0.5/NUM_VOICES+1, 0);
			
			
			for(aVoice in voiceWaveForms){
				
				glTranslated(0, 1.0/NUM_VOICES+1, 0);
				
				NSNumber * anAmplitude;
				
				glBegin(GL_LINE_STRIP);
				
				int i = 0;
				
				for(anAmplitude in aVoice){
					
					glVertex2d((Aspect(@"Floor",0)/resolution)*i, [anAmplitude doubleValue]*PropF(@"amplitude"));
					i++;
				} 
				
				glEnd();
				
			}
		}
		
	} PopSurface();
	
	ApplySurface(@"Wall"); {
		
		if (PropF(@"alphaWall") > 0) {
			
			ofSetColor(255, 255, 255, 255.0*PropF(@"alphaWall"));
			
			NSMutableArray * aVoice = [voiceWaveForms objectAtIndex:0];
			
			glTranslated(0, 0.5, 0);
			
			NSNumber * anAmplitude;
			
			glBegin(GL_LINE_STRIP);
			
			int i = 0;
			
			for(anAmplitude in aVoice){
				
				glVertex2d((Aspect(@"Wall",0)/resolution)*i, [anAmplitude doubleValue]*PropF(@"amplitude"));
				i++;
			} 
			
			glEnd();
			
		}
		
	} PopSurface();
	
}

-(void) controlDraw:(NSDictionary *)drawingInformation{
	
	ofEnableAlphaBlending();
	
	ofFill();
	
	float levelsWidth = ofGetWidth() * 0.9;
	float levelsMargin = ofGetWidth() - levelsWidth;
	
	float bandHeight = ofGetHeight()*0.9/NUM_BANDS;
	
	for(int iVoice = 0; iVoice < NUM_VOICES+1; iVoice++){
		
		NSMutableArray * aVoice = [voiceWaveForms objectAtIndex:iVoice];
		float resolution = [aVoice count];
		
		glPushMatrix(); {
			glTranslated(iVoice*(levelsWidth*1.0/NUM_VOICES), 0, 0);
			ofSetColor(0, 0, 0);
			ofFill();
			
			//			ofDrawBitmapString(ofToString(iVoice+1,0), ofPoint(0.0001,bandHeight*0.75));
			
			glPushMatrix(); {
				
				for (int iBand = NUM_BANDS-1; iBand >= 0; iBand--) {
					
					NSString * propStr;
					
					if(iVoice == 0)
						propStr = [NSString stringWithFormat:@"liveVoiceBand%i", iBand+1];
					else 
						propStr = [NSString stringWithFormat:@"voice%iBand%i", iVoice, iBand+1];
					
					//Full scales
					if (iVoice == 0) {
						ofSetColor(24, 120, 88);
					} else {
						ofSetColor(24, 88, 120);
					}
					ofFill();
					ofRect(0, 0, 
						   (levelsWidth/(NUM_VOICES+1.0)),
						   (bandHeight*0.4)
						   );
					
					ofSetColor(0, 0, 0,127);
					ofSetLineWidth(1.5);
					ofNoFill();
					ofRect(0, 0, 
						   (levelsWidth/(NUM_VOICES+1.0)),
						   (bandHeight*0.4)
						   );
					
					
					//Bars
					if (iVoice == 0) {
						ofSetColor(68, 240, 176);
					} else {
						ofSetColor(68, 176, 240);
					}
					ofFill();
					ofRect(0, 0, 
						   (levelsWidth/(NUM_VOICES+1.0))*PropF(propStr),
						   (bandHeight*0.4)
						   );
					
					ofSetColor(0, 0, 0,127);
					ofSetLineWidth(1.5);
					ofNoFill();
					ofRect(0, 0, 
						   (levelsWidth/(NUM_VOICES+1.0))*PropF(propStr),
						   (bandHeight*0.4)
						   );
					
					// sines
					
					ofNoFill();
					ofSetLineWidth(1.5);
					ofSetColor(255, 255, 63, 63);
					
					glBegin(GL_LINE_STRIP);
					
					for(int a = 0; a < resolution; a++){
						glVertex2d(((levelsWidth/(NUM_VOICES+1.0))/(resolution-1))*a, (bandHeight*0.4*0.5)+(voiceSourceWaves[iVoice][iBand][a]*bandHeight*0.2));
					} 
					
					glEnd();
					
					glTranslated(0,bandHeight*0.5, 0);
					
				}
				
				glTranslated(0,bandHeight*0.25, 0);
				
				if (PropB(@"updateWaveForms")) {
					ofSetColor(0, 0, 0, 127);
				} else {
					ofSetColor(0, 0, 0, 31);
				}
				
				ofFill();
				ofRect(0, 0, (levelsWidth/(NUM_VOICES+1.0)), bandHeight*1.5);
				
				ofSetColor(0, 0, 0,127);
				ofSetLineWidth(1.5);
				ofNoFill();
				ofRect(0, 0, (levelsWidth/(NUM_VOICES+1.0)), bandHeight*1.5);
				
				ofNoFill();
				ofSetLineWidth(1.5);
				ofSetColor(255, 255, 0);
				
				NSNumber * anAmplitude;
				
				glBegin(GL_LINE_STRIP);
				
				int i = 0;
				
				for(anAmplitude in aVoice){
					
					glVertex2d(((levelsWidth/(NUM_VOICES+1.0))/(resolution-1))*i, (bandHeight*1.5*0.5)+([anAmplitude doubleValue]*bandHeight*1.5*0.5));
					i++;
				} 
				
				glEnd();
				
				
			} glPopMatrix();
			
			
		} glPopMatrix();
		
	}
	
	glPushMatrix();{
		glTranslated(0, ofGetHeight(), 0);
		if (PropB(@"recordLive")) {
			ofSetColor(0, 0, 0, 127);
		} else {
			ofSetColor(0, 0, 0, 31);
		}
		ofFill();
		ofRect(0, 0, ofGetWidth(), -bandHeight*2.0);
		ofNoFill();
		ofSetLineWidth(2.0);
		ofSetColor(255, 255, 255, 255.0*0.75);
		
		for(int i=0;i<liveSamples/2;i++){
			float x = ((ofGetWidth()*1.0)/liveSamples)*i*2.0;
			ofLine(x, 0, x, -bandHeight*(magnitude[i]*(10.0/liveSamples)));
		}
		
		ofSetColor(0, 0, 0,127);
		ofSetLineWidth(1.5);
		ofNoFill();
		ofRect(0, 0, ofGetWidth(), -bandHeight*2.0);

		if (PropB(@"recordLive")) {
			ofSetLineWidth(2.0);
			
			glTranslated(0, -bandHeight, 0);
			ofSetColor(0,0,0, 255.0*0.5);
			
			glBegin(GL_LINE_STRIP);
			for(int i=0;i<[liveVoice simplifiedCurve]->size();i++){
				float x = ((ofGetWidth()*1.0)/[liveVoice simplifiedCurve]->size())*i;
				glVertex2f(x, [liveVoice simplifiedCurve]->at([liveVoice simplifiedCurve]->size()-i-1)*bandHeight);	
			}
			glEnd();
		}
		
	}glPopMatrix();
	
}

- (NSMutableArray*) getWaveFormWithIndex:(int)index 
							   amplitude:(float)amplitude 
							  driftSpeed:(float)driftSpeed
							   smoothing:(float)smoothing
							   freqeuncy:(float)frequency
								  random:(float)randomFactor
								  offset:(float)offset
						 withFormerArray:(NSMutableArray*)formerArray
{
	
	NSMutableArray * aVoice;

	if ([voiceWaveForms count]>index) {
				
		int voiceLength = [[voiceWaveForms objectAtIndex:index] count];
		
		int voiceOffset = roundf(offset * voiceLength);
		
		int iFrom = (voiceLength-voiceOffset)%voiceLength;
		
		aVoice = [NSMutableArray arrayWithCapacity:voiceLength];
		
		for (int iTo = 0; iTo < voiceLength; iTo++) {
			[aVoice addObject:[formerArray objectAtIndex: iFrom]];
			iFrom = (iFrom+1)%voiceLength;
		}
		
		float now = ofGetElapsedTimef();
		
		//	if(now - voiceUpdateTimes[index] > 1.0/60){
		
		voiceUpdateTimes[index] = now;
		
		for (int iBand = 0; iBand < NUM_BANDS; iBand++) {
						
			NSString * propStr;

			if(index == 0)
				propStr = [NSString stringWithFormat:@"liveVoiceBand%i", iBand+1];
			else 
				propStr = [NSString stringWithFormat:@"voice%iBand%i", index, iBand+1];
			
			float bandValue = PropF(propStr);
			
			//			double drift = PropF(@"drift")*ofGetElapsedTimef()*(2.0*((iBand-(NUM_BANDS/2))+1.0));
			double drift = driftSpeed*ofGetElapsedTimef()*(iBand+1.0/NUM_BANDS)*2.0*PI;
			double smoothingFactor = 1.0-powf((1.0-sqrt(smoothing)), 2.5);
			double ampRnd = ofRandom(0,randomFactor);
			
			for (int i = 0; i < voiceLength; i++) {
				
				float formerAmplitude;
				if (iBand == 0) {
					formerAmplitude = smoothingFactor*[[aVoice objectAtIndex:i] floatValue];
				} else {
					formerAmplitude = [[aVoice objectAtIndex:i] floatValue];
				}
				
				float amp = sinf((((1.0*i)/voiceLength)*(1.0+iBand))*frequency*PI*2.0/*+(1.0/(1+iBand))*/-drift) * fmaxf(bandValue, ampRnd);
				
				NSNumber * anAmplitude = [NSNumber numberWithFloat:
										  ((1.0/NUM_BANDS) * amp * (1.0-smoothingFactor))
										  +formerAmplitude 
										  ];
				
				voiceSourceWaves[index][iBand][i] = (voiceSourceWaves[index][iBand][i]*smoothingFactor) + (amp * (1.0-smoothingFactor));

				[aVoice replaceObjectAtIndex:i withObject:anAmplitude];
				
			}
			
		}
	
		NSMutableArray * aNewVoice = [NSMutableArray arrayWithCapacity:voiceLength];
		
		iFrom = voiceOffset%voiceLength;
		
		for (int iTo = 0; iTo < voiceLength; iTo++) {
			[aNewVoice addObject:[aVoice objectAtIndex: iFrom]];
			iFrom = (iFrom+1)%voiceLength;
		}
		
		formerArray = aNewVoice;
		aVoice = formerArray;
				
		
	} else {
		aVoice = [NSMutableArray array];
	}
	
	[aVoice retain];

	return aVoice;
	
}

- (NSMutableArray*) getWaveFormBandsWithIndex:(int)index 
									amplitude:(float)amplitude 
								   driftSpeed:(float)driftSpeed
									smoothing:(float)smoothing
									freqeuncy:(float)frequency
									   random:(float)randomFactor
									   offset:(float)offset
							  withFormerArray:(NSMutableArray*)formerArray
{
	
	NSMutableArray * aVoice = [self getWaveFormWithIndex:index 
											   amplitude:amplitude
											  driftSpeed:driftSpeed
											   smoothing:smoothing
											   freqeuncy:frequency
												  random:randomFactor
												  offset:offset
										 withFormerArray:formerArray
							   ];
	
	NSMutableArray * waveFormBands = [NSMutableArray arrayWithCapacity:NUM_BANDS];
	
	int voiceLength = [aVoice count]; 
	
	for (int iBand = 0; iBand < NUM_BANDS; iBand++) {
		
		NSMutableArray * aWave = [NSMutableArray arrayWithCapacity:voiceLength];
		
		for (int i = 0; i < voiceLength; i++) {
			
			[aWave addObject:[NSNumber numberWithFloat:voiceSourceWaves[index][iBand][i]] 
			 ];
			
		}
		
		[waveFormBands addObject:aWave];
		
	}
	
	return waveFormBands;
	
}




- (BOOL) autoresizeControlview{
	return YES;	
}

- (IBAction)inputDeviceSelected:(id)sender
{
	/**
	 int val = [mInputDevices indexOfSelectedItem];
	 AudioDeviceID newDevice =(mInputDeviceList->GetList())[val].mID;
	 
	 if(newDevice != inputDevice)
	 {		
	 //	[self stop:sender];
	 inputDevice = newDevice;
	 //[self resetPlayThrough];
	 }
	 **/
}

/*****
 static void BuildDeviceMenu(AudioDeviceList *devlist, NSPopUpButton *menu, AudioDeviceID initSel)
 {
 [menu removeAllItems];
 
 AudioDeviceList::DeviceList &thelist = devlist->GetList();
 int index = 0;
 for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i, ++index) {
 while([menu itemWithTitle:[NSString stringWithCString: (*i).mName encoding:NSASCIIStringEncoding]] != nil) {
 strcat((*i).mName, " ");
 }
 
 if([menu itemWithTitle:[NSString stringWithCString: (*i).mName encoding:NSASCIIStringEncoding]] == nil) {
 [menu insertItemWithTitle: [NSString stringWithCString: (*i).mName encoding:NSASCIIStringEncoding] atIndex:index];
 
 if (initSel == (*i).mID)
 [menu selectItemAtIndex: index];
 }
 }
 }
 **/

@end
