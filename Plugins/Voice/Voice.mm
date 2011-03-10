//
//  Voice.mm
//  malpais
//
//  Created by ole kristensen on 16/02/11.
//  Copyright 2011 Recoil Performance Group. All rights reserved.
//

#import "Voice.h"
#import "Keystoner.h"


@implementation Voice

-(void) initPlugin{
	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:0.0 maxValue:1.0] named:@"amplitude"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:0.0 maxValue:1.0] named:@"alpha"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:0.0 maxValue:1000.0] named:@"resolution"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:0.0 maxValue:10.0] named:@"frequency"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.45 minValue:0.0 maxValue:1.0] named:@"smoothing"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:0.05] named:@"lineWidth"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:-5.0 maxValue:5.0] named:@"drift"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:1.0] named:@"random"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:NUM_VOICES] named:@"waveChannel"];
	
}

-(void) setup{
	
	waveForms = [NSMutableArray arrayWithCapacity:NUM_BANDS];
	wave = [NSMutableArray arrayWithCapacity:MAX_RESOLUTION];
	
	for (int iAmplitude=0; iAmplitude<MAX_RESOLUTION; iAmplitude++) {
		[wave addObject:[NSNumber numberWithDouble:0.0]];
	}
	
	for(int iBand=0;iBand<NUM_BANDS;iBand++){
		
		NSMutableArray * aBand = [NSMutableArray arrayWithCapacity:MAX_RESOLUTION];
		
		for (int iAmplitude=0; iAmplitude<MAX_RESOLUTION; iAmplitude++) {
			[aBand addObject:[NSNumber numberWithDouble:0.0]];
		}
		
		[waveForms addObject:aBand];
	}
	
}


-(void) update:(NSDictionary *)drawingInformation{
	
	int resolution = (int)roundf(PropF(@"resolution"));
	
	waveForms = [GetPlugin(Wave)getWaveFormBandsWithIndex:(int)roundf(PropF(@"waveChannel"))
												amplitude:1.0 
											   driftSpeed:PropF(@"drift")
												smoothing:PropF(@"smoothing")
												freqeuncy:PropF(@"frequency")
												   random:PropF(@"random")
												   offset:0
										  withFormerArray:wave
				 ];
	
}

-(void) draw:(NSDictionary *)drawingInformation{
	
	float amplitude = PropF(@"amplitude");

	float lineWidth = PropF(@"lineWidth");
	
	ApplySurface(@"Wall");{
		
		ofSetColor(255, 255, 255, 255*PropF(@"alpha"));
		ofFill();
		
		glPushMatrix();{
			
			glTranslated(0, 0.5, 0);
			
			for (int iBand = 0;iBand<NUM_BANDS; iBand++) {

				int resolution = [[waveForms objectAtIndex:iBand] count];
				
				glBegin(GL_QUAD_STRIP);
				ofxPoint2f lastPoint = ofxPoint2f(0,0);
				for (int i = 0;i< resolution; i++) {
					
					float aspect = [self aspect];
					
					float x = ([self aspect]*i)/resolution;
					//					float f = [self falloff:(float)x/PropF(@"falloffStart")] * [self falloff:(1-x)/PropF(@"falloffEnd")];
					ofxPoint2f p = ofxPoint2f(x, [[[waveForms objectAtIndex:iBand] objectAtIndex:i] floatValue]*amplitude);
					ofxVec2f v = p - lastPoint;
					ofxVec2f h = ofxVec2f(-v.y,v.x);
					h.normalize();
					h *= lineWidth;
					glVertex2f((p+h).x, (p+h).y);
					glVertex2f((p-h).x, (p-h).y);				
					lastPoint = p;
				}
				
				glEnd();
				
			}
			
		} glPopMatrix();
		
	} PopSurface();
	
}

-(float) aspect{
	return [[[GetPlugin(Keystoner) getSurface:@"Wall" viewNumber:0 projectorNumber:0] aspect] floatValue];
}



@end