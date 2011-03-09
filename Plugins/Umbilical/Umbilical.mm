#import "Umbilical.h"
#import "Keystoner.h"
#import "Kinect.h"

@implementation Umbilical



-(float) falloff:(float)p{
	if(p >= 1)
		return 1;
	if(p<=0)
		return 0;
	p *= 6;
	p -= 3;
	
	return 1.0/(1.0+pow(5,-p));
}

-(float) offset:(float)x{
	float xScale = 50.0;
	x *= xScale;
	float u = endPos.y*xScale;
	float s = 5;
	float e = 2.71828182845904523536;
	return 20 * (pow(e , -(x-u)/s) )/ pow(s*(1+pow(e , -(x-u)/s)) , 2);
	
}

-(void) initPlugin{
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:0.0 maxValue:1.0] named:@"amplitude"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:0.0 maxValue:1000.0] named:@"resolution"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:0.0 maxValue:10.0] named:@"frequency"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.45 minValue:0.0 maxValue:1.0] named:@"smoothing"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.02 minValue:-2.0 maxValue:2.0] named:@"drift"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:-1.0 maxValue:1.0] named:@"direction"];
	for (int i = 0; i < NUM_VOICES+1; i++) {
		[self addProperty:[BoolProperty boolPropertyWithDefaultvalue:0.0] named: 
		 [NSString stringWithFormat:@"wave%iOn",i]
		 ];
		[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:NUM_VOICES] named:
		 [NSString stringWithFormat:@"wave%iChannel",i]
		 ];
		[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:1.0] named:
		 [NSString stringWithFormat:@"wave%ilength",i]
		 ];
	}
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.5 minValue:0.0 maxValue:1.0] named:@"startPosX"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:1.0] named:@"startPosY"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.01 minValue:0.01 maxValue:1.0] named:@"falloffStart"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.01 minValue:0.01 maxValue:1.0] named:@"falloffEnd"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:1.0] named:@"weighLiveOrBuffer"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:NUM_VOICES] named:@"numberOfFixedStrings"];
	[self addProperty:[BoolProperty boolPropertyWithDefaultvalue:0.0] named:@"stretch"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:1.0] named:@"endpointPushForce"];

	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:0.002] named:@"springForce"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:0.002] named:@"springSecondaryForce"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:0.002] named:@"springGlueForce"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:0.002] named:@"springGlueEndForce"];	
		[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:1] named:@"springRepulsion"];	
	
	[self assignMidiChannel:7];
}

-(void) setup{	
	
	waves = [NSMutableArray arrayWithCapacity:NUM_VOICES+1];
	
	for (int i = 0; i < NUM_VOICES+1; i++) {
		distortion[i] = new MSA::Interpolator1D;
		distortion[i]->reserve((int)roundf(PropF(@"resolution")));
		waveForm[i] =  new MSA::Interpolator1D;
		waveForm[i]->reserve((int)roundf(PropF(@"resolution")));
		
		NSMutableArray * aVoice = [NSMutableArray arrayWithCapacity:MAX_RESOLUTION];
		
		for(int i=0;i<MAX_RESOLUTION;i++){
			[aVoice addObject:[NSNumber numberWithDouble:0.0]];
		}
		
		[waves addObject:aVoice];
		
		bool notOk = true;
		while(notOk){
			notOk = false;
			waveX[i] = ofRandom(0, [self aspect]);
			for(int j=0;j<i;j++){
				if(fabs(waveX[i] - waveX[j]) < 0.02){
					notOk = true;
					cout<<"Damn "<<waveX[i]<<"  "<<waveX[j]<<endl;
				}
			}
		}		
	}
	
	mousex = 0.5 * [self aspect];
	mousey = 0.0;
	
	endPos = ofxPoint2f(0,1);
	
	
	physics = new ofxPhysics2d(ofPoint(0,0.0005));
	physics->checkBounds(true);
	physics->enableCollisions(true);
	physics->setNumIterations(150);
	
	if(particles){
		delete particles;
	}
	particlesLength = 7;
	numStrings = 1;
	particles = new ofxParticle*[numStrings];
	for(int i=0;i<numStrings;i++){
		particles[i] = new ofxParticle[particlesLength];
		for(int x = 0 ; x < particlesLength ;x++)
		{
			ofPoint particlePos = ofPoint(100.0*PropF(@"startPosX"),100.0*(float)x*1.0/particlesLength);
			ofxParticle* p = new ofxParticle(particlePos, 0.00);
			particles[i][x] = *p;
		
			
			if(x == particlesLength-1){
				p->setRadius(10);
			}
			
			physics->add(&particles[0][x]);	
			
			if(x > 0){
				ofxParticle *p1 = &particles[i][x-1];
				ofxParticle *p2 = &particles[i][x];
				float rest = p1->distanceTo(p2);
				
				ofxSpring* s = new ofxSpring(p1, p2, 0, 0);
				physics->add(s);
				if(i == 0){
					springs.push_back(s);				
					p->setMass(1000);
				}
				else 
					secondarySprings.push_back(s);									
			}
			
			if(i > 0){
				ofxParticle *p1 = &particles[i][x];
				ofxParticle *p2 = &particles[0][x];
				float rest = p1->distanceTo(p2);
				
				ofxSpring* s = new ofxSpring(p1, p2, 1, 0);
				physics->add(s);
				
				if(x < particlesLength - 1)
					glueSprings.push_back(s);	
				else 
					glueEndSprings.push_back(s);						
				
			}
		}
		
		moveForce.push_back(ofRandom(0.1, 3.5));
	}
	
	particles[0][particlesLength-1].setMass(100);
	
}

-(void) update:(NSDictionary *)drawingInformation{
	startPos = ofxVec2f(PropF(@"startPosX"), PropF(@"startPosY"));

	
	
	for(int i=0;i<springs.size();i++){
		springs[i]->setStrength(PropF(@"springForce"));
	}
	for(int i=0;i<secondarySprings.size();i++){
		secondarySprings[i]->setStrength(PropF(@"springSecondaryForce"));
	}
	for(int i=0;i<glueSprings.size();i++){
		glueSprings[i]->setStrength(PropF(@"springGlueForce")*moveForce[i/numStrings]);
	}
	for(int i=0;i<glueEndSprings.size();i++){
		glueEndSprings[i]->setStrength(PropF(@"springGlueEndForce")*moveForce[i]);
	}
	
	for(int i=0;i<numStrings;i++){
		
		particles[i][0].moveTo(PropF(@"startPosX")*100.0, 0);
		particles[i][0].stopMotion();
		
		
		if(i == 0){
			ofPoint p = endPos;
			p *= 100;			
			if(p.y > 0)
				particles[i][particlesLength-1].moveTo(p);
		} else {
			for(int u=0;u<numStrings;u++){
			//&	particles[i][particlesLength-1].applyRepulsionForce(particles[u][particlesLength-1], PropF(@"springRepulsion"));
			}

		}
	}
	//

	physics->update();

	/*for(int i=0;i<numStrings;i++){		
		if(i == 0){
			ofPoint p = endPos;
			p *= 100;			
			if(p.y > 0)
				particles[i][particlesLength-1].moveTo(p);
		}
	}*/
	
	
	int resolution = (int)roundf(PropF(@"resolution"));
	
	for (int iVoice = 0; iVoice < NUM_VOICES+1; iVoice++) {
		//Offsets
		{
			while(offsets[iVoice].size() < PropI(@"resolution"))
				offsets[iVoice].push_back(0);
			
			float midDist =  fabs(0.5*[self aspect] - waveX[iVoice]);
			for(int i=0;i<PropI(@"resolution");i++){
				float x = (float)i/PropI(@"resolution");
				float offset = 0;			
				if(PropF(@"endpointPushForce") > 0 && iVoice != 0){
					//Ved det er snyd, men skal finde afstand til endpoint, og snyder
					ofxPoint2f thisPoint = ofxPoint2f(waveX[iVoice], x);
					float dir = 1;
					if(thisPoint.x < 0.5*[self aspect])
						dir = -1;
					
					float xDist = dir*(endPos.x - thisPoint.x)+0.1;
					
					float d = fabs(0.5*[self aspect] - endPos.x)+0.05;
					
					if(xDist > 0){
						offset = -dir*PropF(@"endpointPushForce") * 100 * [self offset:x] * d * xDist;
					} else {
						offset = -dir*PropF(@"endpointPushForce") * 100 * [self offset:x] * d * (xDist)*0.8;
						//offset = xDist;
					}
					
				}
				
				offsets[iVoice][i] += (offset - offsets[iVoice][i]) * pow([self aspect]*0.5 - midDist,2)*9;
			}
		}
		
		
		NSString * waveOnStr = [NSString stringWithFormat:@"wave%iOn",iVoice];
		
		if (iVoice > 0) {
			if (iVoice-1 < NUM_VOICES-PropF(@"numberOfFixedStrings")){
				[[properties objectForKey:waveOnStr] setBoolValue:YES];
			} else {
				[[properties objectForKey:waveOnStr] setBoolValue:NO];
			}
			
		}
		
		if (PropB(waveOnStr)) {
			
			NSString * waveChannelStr = [NSString stringWithFormat:@"wave%iChannel",iVoice];
			
			wave = [GetPlugin(Wave)
					getWaveFormWithIndex:(int)roundf(PropF(waveChannelStr))
					amplitude:1.0 
					driftSpeed:PropF(@"drift")
					smoothing:PropF(@"smoothing")
					freqeuncy:PropF(@"frequency")
					random:0
					offset:0
					withFormerArray:[waves objectAtIndex:iVoice]
					];
			
			[waves replaceObjectAtIndex:iVoice withObject:wave]; 
			
			float direction = PropF(@"direction");
			
			if(direction < 0){
				MSA::Interpolator1D * newDistortion = new MSA::Interpolator1D;
				newDistortion->reserve(resolution);
				for (int i=distortion[iVoice]->size()-1; i >= 0 ; i--) {
					newDistortion->push_back(distortion[iVoice]->getData()[i]);
				}
				distortion[iVoice]->clear();
				delete distortion[iVoice];
				distortion[iVoice] = newDistortion;
			}
			
			if ([wave count] > 0) {
				if(fabs(direction) > 0) {
					distortion[iVoice]->push_back([[wave objectAtIndex:0] floatValue]);
				}
				waveForm[iVoice]->clear();
				for (int i=0; i < [wave count]; i++) {
					waveForm[iVoice]->push_back([[wave objectAtIndex:i] floatValue]);
				}
			}
			
			if (distortion[iVoice]->size() > resolution) {
				MSA::Interpolator1D * newDistortion = new MSA::Interpolator1D;
				newDistortion->reserve(resolution);
				for (int i=distortion[iVoice]->size()-resolution; i < distortion[iVoice]->size() ; i++) {
					newDistortion->push_back(distortion[iVoice]->getData()[i]);
				}
				distortion[iVoice]->clear();
				delete distortion[iVoice];
				distortion[iVoice] = newDistortion;
			}
			
			if(direction < 0){
				MSA::Interpolator1D * newDistortion = new MSA::Interpolator1D;
				newDistortion->reserve(resolution);
				for (int i=distortion[iVoice]->size()-1; i >= 0 ; i--) {
					newDistortion->push_back(distortion[iVoice]->getData()[i]);
				}
				distortion[iVoice]->clear();
				delete distortion[iVoice];
				distortion[iVoice] = newDistortion;
			}
			
		} else {
			//Tøm bufferen forfra hvis den er slået fra
			MSA::Interpolator1D * newDistortion = new MSA::Interpolator1D;
			newDistortion->reserve(resolution);
			for (int i=1; i < distortion[iVoice]->size() ; i++) {
				newDistortion->push_back(distortion[iVoice]->getData()[i]);
			}
			distortion[iVoice]->clear();
			delete distortion[iVoice];
			distortion[iVoice] = newDistortion;			
		}	
		
	}
	
	
	
	if(mouseh < 0){
		
		NSMutableArray * pblobs = [GetPlugin(Kinect) persistentBlobs];
		
		if([pblobs count] >= 1){
			PersistentBlob * oldest = nil;
			for(PersistentBlob * b in pblobs){
				if((oldest == nil || b->age > oldest->age) && [b centroidFiltered].x > 0 && [b centroidFiltered].x < [self aspect])
					oldest = b;
			}
			if(oldest != nil){
				endPos = ofxVec2f([oldest centroidFiltered].x,[oldest centroidFiltered].z);
			}
		}
		
	} else {
		endPos = ofxVec2f(mousex,mousey);
	}
	
}


-(void) drawWave:(int)iVoice from:(ofxPoint2f)begin to:(ofxPoint2f)end{
	ofxVec2f v1 = end-begin;
	ofxVec2f v2 = ofxVec2f(0,1.0);
	
	float length = v1.length();
	
	
	ofSetColor(255, 255, 255);
	for(int i=0;i<numStrings;i++){
		glLineWidth(1);
		glBegin(GL_LINE_STRIP);
		for(int x = 0 ; x < particlesLength ;x++)
		{
			ofxParticle *p1 = &particles[i][x];
			glVertex2f(p1->x/100.0, p1->y/100.0);
		}
		glEnd();
	}
	
	
	glPointSize(8);
	ofSetColor(255, 0, 0);
	glBegin(GL_POINTS);
	for(int i=0;i<numStrings;i++){		
		for(int x = 0 ; x < particlesLength ;x++)
		{
			ofxParticle *p1 = &particles[i][x];
			glVertex2f(p1->x/100.0, p1->y/100.0);
		}
	}
	glEnd();
	
	glPointSize(1);
	
	
	
	glPushMatrix();{
		
		ofNoFill();
		ofSetLineWidth(4);
		
		ofSetColor(255, 255, 255, 255);
		
		glTranslated(begin.x,begin.y, 0);
		glRotated(-v1.angle(v2)+90, 0, 0, 1);
		
		int segments = distortion[iVoice]->size();
		int resolution = PropF(@"resolution");
		float amplitude = PropF(@"amplitude");
		float weighLiveOrBuffer = PropF(@"weighLiveOrBuffer");
		
		int startSegment, endSegment;
		
		if (PropB(@"stretch")) {
			startSegment = segments*begin.y;
			endSegment = segments*end.y;
		} else {
			startSegment = resolution*begin.y;
			endSegment = resolution*end.y;
		}
		glBegin(GL_QUAD_STRIP);
		ofxPoint2f lastPoint = ofxPoint2f(0,0);		
		for (int i = startSegment;i< endSegment; i++) {
			float x = 1.0/(endSegment-startSegment)*(i-startSegment);
			
			if (i < segments) {
				float f = [self falloff:(float)x/PropF(@"falloffStart")] * [self falloff:(1-x)/PropF(@"falloffEnd")];
				ofxPoint2f p = ofxPoint2f(x*length, offsets[iVoice][i]+((distortion[iVoice]->getData()[i]*weighLiveOrBuffer)+(waveForm[iVoice]->sampleAt(x*length)*(1.0-weighLiveOrBuffer)))*amplitude*f);
				ofxVec2f v = p - lastPoint;
				ofxVec2f h = ofxVec2f(-v.y,v.x);
				h.normalize();
				h *= 0.003;
				glVertex2f((p+h).x, (p+h).y);
				glVertex2f((p-h).x, (p-h).y);				
				//				glVertex2f(x*length, offsets[iVoice][i]+((distortion[iVoice]->getData()[i]*weighLiveOrBuffer)+(waveForm[iVoice]->sampleAt(x)*(1.0-weighLiveOrBuffer)))*amplitude*f);
				lastPoint = p;
			}
		}
		glEnd();
		
	} glPopMatrix();
}

-(void) draw:(NSDictionary*)drawingInformation{
	ApplySurface(@"Floor");{
		//	glScaled([self aspect], 1, 1);
		
		[self drawWave:0 from:startPos to:endPos];
		
		for (int iVoice = 1; iVoice < NUM_VOICES+1; iVoice++) {
			NSString * voiceLengthStr = [NSString stringWithFormat:@"wave%ilength",iVoice];
			
			float voiceLength = PropF(voiceLengthStr);
			
			ofxVec2f start = ofxVec2f(waveX[iVoice], 0.0);
			ofxVec2f end = ofxVec2f(waveX[iVoice], voiceLength);
			[self drawWave:iVoice from:start to:end];
		}
		
	}PopSurface();
}

-(void) controlDraw:(NSDictionary *)drawingInformation{
	ofBackground(0, 0, 0);
	ofEnableAlphaBlending();
	ofSetColor(255, 255, 255);
	
	if(mouseh != -1){
		ofEnableAlphaBlending();
		if(mouseh != 0){
			ofNoFill();
		} else {
			ofFill();
		}
		ofSetColor(255, 255, 0,100);
		ofEllipse(mousex*200.0*(1.0/[self aspect]), mousey*400.0, 15, 15);
	}
	
	ofFill();
	
	ofSetColor(255, 0, 255,100);
	ofEllipse(startPos.x*200*(1.0/[self aspect]), startPos.y*400, 15, 15);
	ofEllipse(endPos.x*200*(1.0/[self aspect]), endPos.y*400, 15, 15);
	
	
	glPushMatrix();{
		
		glScaled(200*1.0/[self aspect], 400, 1);
		[self drawWave:0 from:startPos to:endPos];
		
		for (int iVoice = 1; iVoice < NUM_VOICES+1; iVoice++) {
			
			NSString * voiceLengthStr = [NSString stringWithFormat:@"wave%ilength",iVoice];
			
			float voiceLength = PropF(voiceLengthStr);
			
			ofxVec2f start = ofxVec2f(waveX[iVoice], 0.0);
			ofxVec2f end = ofxVec2f(waveX[iVoice], voiceLength);
			[self drawWave:iVoice from:start to:end];
		}
		
	}glPopMatrix();
}

-(void) controlMousePressed:(float)x y:(float)y button:(int)button{
	mousex = [self aspect] * x / 200.0;
	mousey = y / 400.0;
	mouseh = (controlMouseFlags & NSShiftKeyMask)?0.0:10.0;	
}

-(void) controlMouseDragged:(float)x y:(float)y button:(int)button{
	mousex = [self aspect] * x / 200.0;
	mousey = y / 400.0;
	mouseh = (controlMouseFlags & NSShiftKeyMask)?0.0:10.0;	
}

-(void) controlMouseReleased:(float)x y:(float)y{
	mouseh = -1;	
}

-(float) aspect{
	return [[[GetPlugin(Keystoner) getSurface:@"Floor" viewNumber:0 projectorNumber:0] aspect] floatValue];
}

@end
