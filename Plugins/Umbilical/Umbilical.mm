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
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:70.0 minValue:1.0 maxValue:MAX_RESOLUTION] named:@"resolution"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1.0 minValue:0.0 maxValue:10.0] named:@"frequency"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.1 minValue:0.0 maxValue:1.0] named:@"smootingRise"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.35 minValue:0.0 maxValue:1.0] named:@"smoothingFall"];
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
		[Prop( ([NSString stringWithFormat:@"wave%ilength",i]) ) setMidiSmoothing:0.7];
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
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:1] named:@"lineWidth"];	
	[self addProperty:[BoolProperty boolPropertyWithDefaultvalue:0.0] named:@"kinect"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0.0 maxValue:1] named:@"trackingAlpha"];	
	
	[self assignMidiChannel:7];
	
	
	waveForms = [NSMutableArray arrayWithCapacity:NUM_BANDS];
	
	for(int iBand=0;iBand<NUM_BANDS;iBand++){
		
		WaveArray * aBand = [[WaveArray alloc]init];
		
		for (int iAmplitude=0; iAmplitude<MAX_RESOLUTION; iAmplitude++) {
			[aBand addFloat:0.0];
		}
		
		[waveForms addObject:aBand];
	}
	
	[waveForms retain];
}

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
	if(object == Prop(@"Enabled")){
		endPos = startPos + ofxVec2f(0,0.1);
	}
}

-(void) setup{	
	aspectCache = [[[GetPlugin(Keystoner) getSurface:@"Floor" viewNumber:0 projectorNumber:0] aspect] floatValue];
	
	
	sceneX = GetPlugin(SceneX);
	voices = [NSMutableArray arrayWithCapacity:NUM_VOICES+1];
	
	for (int i = 0; i < NUM_VOICES+1; i++) {
		distortion[i] = new MSA::Interpolator1D;
		distortion[i]->reserve((int)roundf(PropF(@"resolution")));
		waveForm[i] =  new MSA::Interpolator1D;
		waveForm[i]->reserve((int)roundf(PropF(@"resolution")));
		
		[voices addObject:[NSNull null]];
		
		/*
		 bool notOk = true;
		 while(notOk){
		 notOk = false;
		 waveX[i] = ofRandom(0, [self aspect]);
		 for(int j=0;j<i;j++){
		 if(fabs(waveX[i] - waveX[j]) < 0.017){
		 notOk = true;
		 //	cout<<"Damn "<<waveX[i]<<"  "<<waveX[j]<<endl;
		 }
		 }
		 }*/
		
		waveX[i] = [self aspect]*( (float) i/NUM_VOICES - 0.5*1/NUM_VOICES);			
		
	}
	
	mousex = 0.5 * [self aspect];
	mousey = 0.0;
	
	endPos = ofxPoint2f([self aspect]*0.5,0.01);
	
	physics = new ofxPhysics2d(ofPoint(0,0.0005));
	physics->checkBounds(NO);
	physics->enableCollisions(true);
	physics->setNumIterations(150);
	
	if(particles){
		delete particles;
	}
	particlesLength = 7;
#ifdef SINGELMODE
	numStrings = 2;
#else
	numStrings = 10;
#endif
	particles = new ofxParticle*[numStrings];
	springInterpolator = new MSA::Interpolator2D*[numStrings];
	
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
		
		moveForce.push_back(ofRandom(0.3, 3.5));
		
		springInterpolator[i] = new MSA::Interpolator2D;
		springInterpolator[i]->reserve(particlesLength);
		springInterpolator[i]->setUseLength(YES);
		
	}
	
	particles[0][particlesLength-1].setMass(100);
	
	gradient.loadImage([[[NSBundle mainBundle] pathForResource:@"gradient" ofType:@"png" inDirectory:@""] cString]);
	
	
	
}

-(void) update:(NSDictionary *)drawingInformation{
	startPos = ofxVec2f(PropF(@"startPosX"), PropF(@"startPosY"));
	
	aspectCache = [[[GetPlugin(Keystoner) getSurface:@"Floor" viewNumber:0 projectorNumber:0] aspect] floatValue];
	
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
		for(int u=0;u<particlesLength;u++){
			ofPoint vel = particles[i][u].getVel();
			float velMag = sqrtf(vel.x*vel.x + vel.y*vel.y);
			
			float max = 0.01;
			if(velMag > max)
				particles[i][u].setSpeed(max);
		}
		
		
		
		particles[i][0].moveTo(PropF(@"startPosX")*100.0, 100.0*[sceneX getBackline:1]);
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
		
		springInterpolator[i]->clear();
		for(int u=0;u<particlesLength;u++){
			springInterpolator[i]->push_back(MSA::Vec2<float>(particles[i][u].x/100.0,particles[i][u].y/100.0));
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

	int updateDriftTimes = 0;
	while(ofGetElapsedTimeMillis() - timer > 16){
		timer += 16;
		updateDriftTimes ++;
	}
	timer = ofGetElapsedTimeMillis();
	
	for (int iVoice = 0; iVoice < NUM_VOICES+1; iVoice++) {
		//Offsets
		{
			while(offsets[iVoice].size() < PropI(@"resolution"))
				offsets[iVoice].push_back(0);
			
			float midDist =  fabs(0.5*[self aspect] - waveX[iVoice]);
			for(int i=0;i<PropI(@"resolution");i++){
				float x = (1.0-[sceneX getBackline:1])*(float)i/PropI(@"resolution") + [sceneX getBackline:1];
				float offset = 0;			
				if(actualPushForce > 0 && iVoice != 0){
					//Ved det er snyd, men skal finde afstand til endpoint, og snyder
					ofxPoint2f thisPoint = ofxPoint2f(waveX[iVoice], x);
					float dir = 1;
					if(thisPoint.x < 0.5*[self aspect])
						dir = -1;
					
					float xDist = dir*(leftPoint.x - thisPoint.x)+0.1;
					float d = fabs(0.5*[self aspect] - leftPoint.x)+0.05;
					if(dir > 0){
						xDist = dir*(rightPoint.x - thisPoint.x)+0.1;
						d = fabs(0.5*[self aspect] - rightPoint.x)+0.05;
					}
					
					
					if(xDist > 0){
						offset = -dir*actualPushForce * 100 * [self offset:x] * d * xDist;
					} else {
						offset = -dir*actualPushForce * 100 * [self offset:x] * d * (xDist)*0.8;
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
			
			NSDictionary * currentVoice = [voices objectAtIndex:iVoice];
			
			NSDictionary * newVoice = [GetPlugin(Wave)getVoiceWithIndex:(int)roundf(PropF(waveChannelStr))
															  amplitude:1.0
															   preDrift:PropF(@"drift")
															  postDrift:0
														  smoothingRise:PropF(@"smoothingRise")
														  smoothingFall:PropF(@"smoothingFall")
															  smoothing:PropF(@"smoothing")
															  freqeuncy:PropF(@"frequency")
															 resolution:PropF(@"resolution")
																 random:0
																 offset:0
												   withFormerDictionary:currentVoice
									   ];
			
			[voices replaceObjectAtIndex:iVoice withObject:newVoice];
			
			if(iVoice == 0){
				
				NSMutableArray * newWaveForms = [newVoice objectForKey:@"bandLines"];	
				int voiceLength = [[newWaveForms objectAtIndex:0] count];
				
				NSMutableArray * oldWaveForms = [NSMutableArray arrayWithArray:waveForms];	
				
				[waveForms removeAllObjects];
				
				float postDrift = PropF(@"drift");
				
				for(int iBand=0;iBand<NUM_BANDS;iBand++){
					
					WaveArray * aBand = [[WaveArray alloc]init];
					
					for (int iAmplitude=0; iAmplitude<voiceLength; iAmplitude++) {
						
						int iFrom = iAmplitude;
						if(postDrift != 0){
							iFrom += (postDrift>0)?-1:1;
							iFrom = (iFrom+voiceLength)%voiceLength;
						}
						
						double postDriftBalance = 1.0-powf((1.0-sqrt(fabs(postDrift))), 2.0);
						
						if([[newWaveForms objectAtIndex:iBand] count] == [[oldWaveForms objectAtIndex:iBand] count]){
							[aBand addFloat:
							 ((1.0-postDriftBalance)*[[newWaveForms objectAtIndex:iBand] getFloatAtIndex:iAmplitude])+
							 ((postDriftBalance)*[[oldWaveForms objectAtIndex:iBand] getFloatAtIndex:iFrom])
							 ];
						} else {
							[aBand addFloat:[[newWaveForms objectAtIndex:iBand] getFloatAtIndex:iAmplitude]];
						}
						
						
					}
					
					[waveForms addObject:aBand];
				}
				
				
			}
			
			wave = [newVoice objectForKey:@"waveLine"];
			for(int q=0;q<updateDriftTimes;q++){
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
						distortion[iVoice]->push_back([wave getFloatAtIndex:0]);
					}
					waveForm[iVoice]->clear();
					for (int i=0; i < [wave count]; i++) {
						waveForm[iVoice]->push_back([wave getFloatAtIndex:i]);
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
	

	
	if(PropB(@"kinect")){
		Kinect * kinect = GetPlugin(Kinect);
		NSMutableArray * pblobs = [kinect persistentBlobs];
		BOOL blobFound = NO;
		if([pblobs count] >= 1){
			PersistentBlob * oldest = nil;
			for(PersistentBlob * b in pblobs){
				if(b->age > 20 && (oldest == nil || b->age > oldest->age) && [b centroidFiltered].x > 0 && [b centroidFiltered].x < [self aspect])
					oldest = b;
			}
			if(oldest != nil){
				blobFound = YES;
				endPos += (ofxVec2f([oldest centroidFiltered].x,[oldest centroidFiltered].z)-endPos)*0.2;
				
				xn::DepthMetaData dmd;
				[kinect getDepthGenerator]->getXnDepthGenerator().GetMetaData(dmd);	
				const XnDepthPixel* pixels = dmd.Data();
				
				ofxVec2f p = ofxVec2f([oldest getLeftmostPoint]);				
				if(pixels[(int)(p.x*640+p.y*480*640)] > 0){
					ofxPoint3f kinectLeftPoint = ofxPoint3f(p.x*640, p.y*480, pixels[(int)(p.x*640+p.y*480*640)]);
					
					ofxPoint3f l = [kinect convertWorldToFloor:[kinect convertKinectToWorld:kinectLeftPoint]];				
					leftPoint += (ofxPoint2f(l.x,l.z) - leftPoint) * 0.2;
					//cout<<ofxPoint2f(l.x,l.z).x<<"  "<<ofxPoint2f(l.x,l.z).y<<endl;
				}
				
				ofxVec2f p2 = ofxVec2f([oldest getRightmostPoint]);				
				if(pixels[(int)(p2.x*640+p2.y*480*640)] > 0){
					ofxPoint3f kinectRightPoint = ofxPoint3f(p2.x*640, p2.y*480, pixels[(int)(p2.x*640+p2.y*480*640)]);
					
					ofxPoint3f r = [kinect convertWorldToFloor:[kinect convertKinectToWorld:kinectRightPoint]];				
					rightPoint += (ofxPoint2f(r.x,r.z) - rightPoint) * 0.2;
					//cout<<ofxPoint2f(l.x,l.z).x<<"  "<<ofxPoint2f(l.x,l.z).y<<endl;
				}
				
			} 
		}
		
		if(blobFound){
			actualPushForce += (PropF(@"endpointPushForce")-actualPushForce) * 0.05;			
		} else {
			actualPushForce += (0-actualPushForce) * 0.05;
		}		
	} else if (mouseh >= 0) {
		actualPushForce += (PropF(@"endpointPushForce")-actualPushForce) * 0.05;
		endPos +=  (ofxVec2f(mousex,mousey) - endPos)*0.2;
	} else {
		actualPushForce += (0-actualPushForce) * 0.05;
	}
}


-(void) drawWave:(int)iVoice from:(ofxPoint2f)begin to:(ofxPoint2f)end{
	ofEnableAlphaBlending();
	
	
	ofxVec2f v1 = end-begin;
	ofxVec2f v2 = ofxVec2f(0,1.0);
	
	float length = v1.length();
	
	
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
	
	
	if(iVoice==0){
		int u=0;
		if(numStrings > 1)
			u = 1;
		
		
		//---&
		/*
		 for (int iBand = 0;iBand<NUM_BANDS; iBand++) {
		 
		 int resolution = [[waveForms objectAtIndex:iBand] count];
		 
		 glBegin(GL_QUAD_STRIP);
		 ofxPoint2f lastPoint = ofxPoint2f(0,0);
		 for (int i = 0;i< resolution; i++) {
		 
		 float aspect = [self aspect];
		 
		 float x = ([self aspect]*i)/resolution;
		 //					float f = [self falloff:(float)x/PropF(@"falloffStart")] * [self falloff:(1-x)/PropF(@"falloffEnd")];
		 ofxPoint2f p = ofxPoint2f(x, [[[waveForms objectAtIndex:iBand] objectAtIndex:i] floatValue]*amplitude);
		 p.y *= 1*(1-PropF(@"falloffStrength")) + PropF(@"falloffStrength")*[self falloff:x*1.0/PropF(@"falloff")]*[self falloff:([self aspect]-x)*1.0/PropF(@"falloff")];
		 ofxVec2f v = p - lastPoint;
		 ofxVec2f h = ofxVec2f(-v.y,v.x);
		 h.normalize();
		 h *= lineWidth;
		 glVertex2f((p+h).x, (p+h).y);
		 glVertex2f((p-h).x, (p-h).y);				
		 lastPoint = p;
		 }
		 
		 glEnd();
		 
		 }*/
		//---/
		
		
		
		for(u;u<numStrings;u++){
			endSegment = segments;
			
			int band = u % 6 + 1;
			
			ofSetColor(255, 255, 255);
			
			glPushMatrix();{
				
				ofNoFill();
				
				ofSetColor(255, 255, 255, PropF(@"trackingAlpha")*255.0);
				
				gradient.getTextureReference().bind();
				glBegin(GL_QUAD_STRIP);
				ofxPoint2f lastPoint = ofxPoint2f(0,0);		
				for (int i = startSegment;i< endSegment; i++) {
					float x = 1.0/(endSegment-startSegment)*(i-startSegment);
					if (i < segments) {
						float f = [self falloff:(float)x/PropF(@"falloffStart")] * [self falloff:(1-x)/PropF(@"falloffEnd")];
						//float val = [[[waveForms objectAtIndex:band] objectAtIndex:i] floatValue]*amplitude*f;
						float val = offsets[iVoice][i]+((distortion[iVoice]->getData()[i]*weighLiveOrBuffer)+(waveForm[iVoice]->sampleAt(x*length)*(1.0-weighLiveOrBuffer)))*amplitude*f;
						//	ofxPoint2f p = ofxPoint2f(offsets[iVoice][i]+((distortion[iVoice]->getData()[i]*weighLiveOrBuffer)+(waveForm[iVoice]->sampleAt(x*length)*(1.0-weighLiveOrBuffer)))*amplitude*f, 0);
						ofxPoint2f p = ofxPoint2f(val, 0);
						MSA::Vec2<float> springP = springInterpolator[u]->sampleAt(x);
						p += ofxPoint2f(springP.x, springP.y);
						ofxVec2f v = p - lastPoint;
						ofxVec2f h = ofxVec2f(-v.y,v.x);
						h.normalize();
						h *= 0.006*PropF(@"lineWidth");
						
						glTexCoord2f(0,x*300);
						glVertex2f((p+h).x, (p+h).y);
						glTexCoord2f(100,x*300);
						glVertex2f((p-h).x, (p-h).y);				
						//				glVertex2f(x*length, offsets[iVoice][i]+((distortion[iVoice]->getData()[i]*weighLiveOrBuffer)+(waveForm[iVoice]->sampleAt(x)*(1.0-weighLiveOrBuffer)))*amplitude*f);
						lastPoint = p;
					}
				}
				glEnd();
				
				gradient.getTextureReference().unbind();
			} glPopMatrix();
			
		}
		
	} else {
		begin.y = [sceneX getBackline:1];
		
		
		
		glPushMatrix();{
			
			ofNoFill();
			ofSetLineWidth(4);
			
			ofSetColor(255, 255, 255, 255);
			
			glTranslated(begin.x,begin.y, 0);
			glRotated(-v1.angle(v2)+90, 0, 0, 1);
			glScaled(1.0-[sceneX getBackline:1], 1, 1);
			
			gradient.getTextureReference().bind();
			
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
					h *= 0.006*PropF(@"lineWidth");;
					glTexCoord2f(0,0);
					glVertex2f((p+h).x, (p+h).y);
					glTexCoord2f(100,0);
					glVertex2f((p-h).x, (p-h).y);				
					//				glVertex2f(x*length, offsets[iVoice][i]+((distortion[iVoice]->getData()[i]*weighLiveOrBuffer)+(waveForm[iVoice]->sampleAt(x)*(1.0-weighLiveOrBuffer)))*amplitude*f);
					lastPoint = p;
				}
			}
			glEnd();
			gradient.getTextureReference().unbind();
			
			
		} glPopMatrix();
		
	}
}

-(void) draw:(NSDictionary*)drawingInformation{
	ApplySurface(@"Floor");{
		//	glScaled([self aspect], 1, 1);
		
		if(PropB(@"wave0On")){
			[self drawWave:0 from:startPos to:endPos];
		}
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
	
	ofSetColor(255, 0, 100,100);
	
	ofEllipse(leftPoint.x*200*(1.0/[self aspect]), leftPoint.y*400, 8, 8);
	ofEllipse(rightPoint.x*200*(1.0/[self aspect]), rightPoint.y*400, 8, 8);
	
	
	ofLine(endPos.x*200*(1.0/[self aspect]), endPos.y*400,  leftPoint.x*200*(1.0/[self aspect]) ,endPos.y*400);
	ofLine(endPos.x*200*(1.0/[self aspect]), endPos.y*400,  rightPoint.x*200*(1.0/[self aspect]) ,endPos.y*400);
	
	
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
	return aspectCache;
}

@end
