#import "Kinect.h"

#import "Keystoner.h"

@implementation Kinect

-(void) initPlugin{
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:-30 maxValue:30] named:@"angle1"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:-30 maxValue:30] named:@"angle2"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:-30 maxValue:30] named:@"angle3"];
	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:4] named:@"priority0"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:4] named:@"priority1"];
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0.0 minValue:0 maxValue:4] named:@"priority2"];
	
	if([customProperties valueForKey:@"point0a"] == nil){
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point0a"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point0b"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point0x"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point0y"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point0z"];
		
		[customProperties setValue:[NSNumber numberWithInt:1] forKey:@"point1a"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point1b"];
		[customProperties setValue:[NSNumber numberWithInt:1] forKey:@"point1x"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point1y"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point1z"];
		
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point2a"];
		[customProperties setValue:[NSNumber numberWithInt:1] forKey:@"point2b"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point2x"];
		[customProperties setValue:[NSNumber numberWithInt:1] forKey:@"point2y"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"point2z"];		
		
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"proj0x"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"proj0y"];
		
		[customProperties setValue:[NSNumber numberWithInt:1] forKey:@"proj1x"];
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"proj1y"];
		
		[customProperties setValue:[NSNumber numberWithInt:0] forKey:@"proj2x"];
		[customProperties setValue:[NSNumber numberWithInt:1] forKey:@"proj2y"];
		
	}
	
	stop = NO;
	draggedPoint = -1;
	
	for(int i=0;i<3;i++){
		dancers[i].userId = -1;
		dancers[i].state = 0;
	}
}

-(void) setup{
	//ofSetLogLevel(OF_LOG_VERBOSE);	
	context.setup();
	
	kinectConnected = depth.setup(&context);
	
	if(kinectConnected){
		users.setup(&context, &depth);		
		[self calculateMatrix];	 
	}
}

-(void) update:(NSDictionary *)drawingInformation{
	if(!stop && kinectConnected){
		context.update();
		depth.update();
		users.update();		
		
		vector<ofxTrackedUser*> vusers = users.getFoundUsers(); 
		
		int numberNonstoredUsers = 0;
		
		bool dancerFound[3];
		for(int i=0;i<3;i++)
			dancerFound[i] = false;
		
		for(int i=0;i<vusers.size();i++){
			//------
			//Uncalibrated user
			if(vusers[i]->is_found && !vusers[i]->is_tracked){
				for(int p=1;p<4;p++){
					int dancer = -1;
					for(int d=0;d<3;d++){
						if(PropI(([NSString stringWithFormat:@"priority%i",d])) == p && dancers[i].state == 1){
							//Prioritering passer, og danseren har ikke nogen user tilknyttet, men har en calibration
							dancer = d;
						}
					}
					if(dancer >= 0){
						ofxTrackedUser * user = vusers[i];
						if(users.getXnUserGenerator().GetSkeletonCap().IsCalibrationData(dancer)){
							NSLog(@"Load calibration");
							users.stopPoseDetection(user->id);
							
							XnStatus status = users.getXnUserGenerator().GetSkeletonCap().LoadCalibrationData(user->id,dancer);
							users.startTracking(user->id);
							dancers[dancer].userId = user->id;
							if(!status){
								dancers[dancer].state = 2;
							}
						}						
					}
				}
			}
			
			//------
			//Calibrated user
			if(vusers[i]->is_tracked){
				bool matchingUser = NO;
				for(int j=0;j<3;j++){
					if(vusers[i]->id == dancers[j].userId){
						matchingUser = YES;
						dancerFound[j] = true;
					}
				}
				if(!matchingUser)
					numberNonstoredUsers++;
			}
			
			
			//			printf("User %i: Is Calibrating %i, is tracking %i \n",i, vusers[i]->is_calibrating, vusers[i]->is_tracked);
			//	printf("User %i:  \n",i);
		}
		
		//------
		//Update gui
		for(int j=0;j<3;j++){
			NSTextField * label;
			switch (j) {
				case 0:
					label = labelA;
					break;
				case 1:
					label = labelB;
					break;
				case 2:
					label = labelC;
					break;						
				default:
					break;
			}
			
			if(dancerFound[j] && dancers[j].state > 0){
				dancerFound[j] = true;
				[label setStringValue:@"Tracking"];
				dancers[j].state = 2;
			} else if(dancers[j].state > 0){
				[label setStringValue:@"Searching"];	
				dancers[j].state = 1;
			} else {
				[label setStringValue:@"No calibration!"];		
			}
		}
		
		if(numberNonstoredUsers == 1){
			[storeA setEnabled:true];
		} else {
			[storeA setEnabled:false];	
		}
	}
}

-(void) draw:(NSDictionary *)drawingInformation{
	if([drawCalibration state]){
		ApplySurface(@"Floor");
		
		ofxPoint2f projHandles[3];	
		projHandles[0] = [self projPoint:0];
		projHandles[1] = [self projPoint:1];
		projHandles[2] = [self projPoint:2];
		
		ofFill();
		//Y Axis 
		ofSetColor(0, 255, 0);
		ofCircle(projHandles[0].x,projHandles[0].y, 10/640.0);
		
		//X Axis
		ofSetColor(255, 0, 0);
		ofCircle(projHandles[1].x,projHandles[1].y, 10/640.0);
		ofLine(projHandles[0].x, projHandles[0].y, projHandles[1].x, projHandles[1].y);
		
		//Z Axis
		ofSetColor(0, 0, 255);
		ofCircle(projHandles[2].x,projHandles[2].y, 10/640.0);
		ofLine(projHandles[0].x, projHandles[0].y, projHandles[2].x, projHandles[2].y);
		
		
		PopSurface();
	}
}

-(void) controlDraw:(NSDictionary *)drawingInformation{
	ofBackground(0, 0, 0);
	
	if(!kinectConnected){
		ofSetColor(255, 255, 255);
		ofDrawBitmapString("Kinect not connected", 640/2-80, 480/2-8);
	} else {
		
		ofxPoint3f points[3];
		ofxPoint2f handles[3];
		ofxPoint2f projHandles[3];
		
		points[0] = [self point3:0];
		points[1] = [self point3:1];
		points[2] = [self point3:2];
		
		handles[0] = [self point2:0];
		handles[1] = [self point2:1];
		handles[2] = [self point2:2];
		
		projHandles[0] = [self projPoint:0];
		projHandles[1] = [self projPoint:1];
		projHandles[2] = [self projPoint:2];
		
		
		glPushMatrix();{
			glScaled(0.5, 0.5, 1.0);
			users.draw();
		}glPopMatrix();
		
		//----------
		//Depth image
		glPushMatrix();{
			glTranslated(0, 0, 0);
			glScaled((640/2), (480/2), 1);
			
			ofNoFill();
			//Y Axis 
			ofSetColor(0, 255, 0);
			ofCircle(handles[0].x,handles[0].y, 10/640.0);
			
			//X Axis
			ofSetColor(255, 0, 0);
			ofCircle(handles[1].x,handles[1].y, 10/640.0);
			ofLine(handles[0].x, handles[0].y, handles[1].x, handles[1].y);
			
			//Z Axis
			ofSetColor(0, 0, 255);
			ofCircle(handles[2].x,handles[2].y, 10/640.0);
			ofLine(handles[0].x, handles[0].y, handles[2].x, handles[2].y);
		}glPopMatrix();
		ofSetColor(255, 255, 255);
		ofDrawBitmapString("Depthimage", 10, 10);
		
		
		//----------
		//Top view
		glPushMatrix();{
			glTranslated((640/2), 0, 0);
			glScaled((640/2), (480/2), 1);
			
			glTranslated(0.5, 0, 0);
			glScaled(1.0/4000.0, 1.0/4000.0, 1);
			
			ofFill();
			//Y Axis 
			ofSetColor(0, 255, 0);
			ofCircle(points[0].x,points[0].z, 2000*10/640.0);
			
			//X Axis
			ofSetColor(255, 0, 0);
			ofCircle(points[1].x,points[1].z, 2000*10/640.0);
			ofLine(points[0].x, points[0].z, points[1].x, points[1].z);
			
			//Z Axis
			ofSetColor(0, 0, 255);
			ofCircle(points[2].x,points[2].z, 2000*10/640.0);
			ofLine(points[0].x, points[0].z, points[2].x, points[2].z);
			
		}glPopMatrix();
		ofSetColor(255, 255, 255);
		ofDrawBitmapString("TOP - Kinect world", (640/2)+10, 10);
		
		//----------
		//Projectionview
		glPushMatrix();{
			glTranslated(0, 480/2, 0);
			glScaled((640/2), (480/2), 1);
			glScaled(640/480, 1, 1);
			glTranslated(0.5, 0.5, 0);
			
			float aspect = [self floorAspect];
			ofFill();
			ofSetColor(70, 70, 70);
			if(aspect < 1){
				glTranslated(-aspect/2, -0.5, 0);
			} else {
				glTranslated(-0.5, -(1.0/aspect)/2.0, 0);
				glScaled(1.0/aspect, 1.0/aspect, 1);
			}
			
			ofRect(0,0,aspect, 1);
			ofNoFill();
			ofSetColor(120, 120, 120);
			ofRect(0,0,aspect, 1);
			
			ofFill();
			//Y Axis 
			ofSetColor(0, 255, 0);
			ofCircle(projHandles[0].x,projHandles[0].y, 10/640.0);
			
			//X Axis
			ofSetColor(255, 0, 0);
			ofCircle(projHandles[1].x,projHandles[1].y, 10/640.0);
			ofLine(projHandles[0].x, projHandles[0].y, projHandles[1].x, projHandles[1].y);
			
			//Z Axis
			ofSetColor(0, 0, 255);
			ofNoFill();
			ofCircle(projHandles[2].x,projHandles[2].y, 10/640.0);
			ofLine(projHandles[0].x, projHandles[0].y, projHandles[2].x, projHandles[2].y);
			
			
		}glPopMatrix();
		ofSetColor(255, 255, 255);
		ofDrawBitmapString("TOP - Floorspace", 10, 480/2+10);
		
		//----------	
		//Mixed view
		glPushMatrix();{
			glTranslated(640/2, 480/2, 0);	
			glScaled((640/2), (480/2), 1);
			glScaled(640/480, 1, 1);
			glTranslated(0.5, 0.5, 0);
			
			float aspect = [self floorAspect];
			ofFill();
			ofSetColor(70, 70, 70);
			if(aspect < 1){
				glTranslated(-aspect/2, -0.5, 0);
			} else {
				glTranslated(-0.5, -(1.0/aspect)/2.0, 0);
				glScaled(1.0/aspect, 1.0/aspect, 1);
			}
			
			ofRect(0,0,aspect, 1);
			ofNoFill();
			ofSetColor(120, 120, 120);
			ofRect(0,0,aspect, 1);
			
			ofxPoint3f kinect = [self convertWorldToFloor:ofxPoint3f(0,0,0)];
			ofxPoint3f p1 = [self convertWorldToFloor:points[0]];		
			ofxPoint3f p2 = [self convertWorldToFloor:points[1]];		
			ofxPoint3f p3 = [self convertWorldToFloor:points[2]];		
			
			ofxPoint3f lfoot, rfoot, lhand, rhand;
			if(users.getTrackedUsers().size() > 0){
				ofxTrackedUser * user = users.getTrackedUser(0);
				lfoot = [self convertWorldToFloor:user->left_lower_leg.worldEnd];
				rfoot = [self convertWorldToFloor:user->right_lower_leg.worldEnd];
				lhand = [self convertWorldToFloor:user->left_lower_arm.worldEnd];
				rhand = [self convertWorldToFloor:user->right_lower_arm.worldEnd];
				
			}
			
			ofSetLineWidth(1);
			ofFill();
			ofSetColor(255, 255, 0);
			ofCircle(kinect.x, kinect.z, 10.0/640);
			ofSetColor(0, 255, 0);
			ofCircle(p1.x, p1.z, 10.0/640);
			ofSetColor(255, 0, 0);
			ofCircle(p2.x, p2.z, 10.0/640);
			ofSetColor(0, 0, 255);
			ofCircle(p3.x, p3.z, 10.0/640);
			
			ofEnableAlphaBlending();
			ofNoFill();
			ofSetColor(0, 255, 0, 255);
			ofCircle(lfoot.x, lfoot.z, 15.0/640);
			ofFill();
			ofSetColor(0, 255, 0, 255*(1-lfoot.y/500.0));
			ofCircle(lfoot.x, lfoot.z, 15.0/640);
			
			ofNoFill();
			ofSetColor(255, 0, 0, 255);
			ofCircle(rfoot.x, rfoot.z, 15.0/640);
			ofFill();
			ofSetColor(255, 0, 0, 255*(1-rfoot.y/500.0));
			ofCircle(rfoot.x, rfoot.z, 15.0/640);
			
			ofNoFill();
			ofSetColor(255, 255, 0, 255);
			ofCircle(lhand.x, lhand.z, 15.0/640);
			ofFill();
			ofSetColor(255, 255, 0, 255*(1-lhand.y/500.0));
			ofCircle(lhand.x, lhand.z, 15.0/640);
			
			
			ofNoFill();
			ofSetColor(0, 255, 244, 255);
			ofCircle(rhand.x, rhand.z, 15.0/640);
			ofFill();
			ofSetColor(0, 255, 255, 255*(1-rhand.y/500.0));
			ofCircle(rhand.x, rhand.z, 15.0/640);
			
		}glPopMatrix();
		ofSetColor(255, 255, 255);
		ofDrawBitmapString("TOP - Mixed world", 640/2+10, 480/2+10);
		
		
		ofSetColor(255, 255, 255);
		ofLine((640/2), 0, (640/2), 480);
		ofLine(0, (480/2), 640, (480/2));	
	}
}

-(void) calculateMatrix{
	ofxVec2f v1, v2, v3;
	ofxPoint3f points[3];
	ofxPoint2f projHandles[3];
	
	points[0] = [self point3:0];
	points[1] = [self point3:1];
	points[2] = [self point3:2];
	
	projHandles[0] = [self projPoint:0];
	projHandles[1] = [self projPoint:1];
	projHandles[2] = [self projPoint:2];	
	
	//Angle 1 er y akse rotation. Vinklen mellem de to blå akser (2)
	v1 = ofxVec2f((points[2]-points[0]).x,(points[2]-points[0]).z);
	v2 = -ofxVec2f((projHandles[2]-projHandles[0]).x,(projHandles[2]-projHandles[0]).y);	
	v3 = ofxVec2f(0,-1);	
	float angle1 = +v1.angle(v3) + v2.angle(v3);
	
	
	//Angle 3 er z akse rotation. Den er fastdefineret i gulvspace
	v1 = ofxVec2f((points[2]-points[0]).z,(points[2]-points[0]).y);
	v2 = ofxVec2f(-1,0);	
	float angle3 = v1.angle(v2);
	
	[Prop(@"angle1") setFloatValue:angle1];
	[Prop(@"angle3") setFloatValue:angle3];
	
	rotationMatrix.makeRotationMatrix( PropF(@"angle1")*DEG_TO_RAD, ofxVec3f(0,1,0),
									  0, ofxVec3f(0,0,1),
									  PropF(@"angle3")*DEG_TO_RAD, ofxVec3f(1,0,0));
	
	//Angle 2 er x akse rotation. Rød akse (transformeret)
	ofxVec3f v = (points[1]-points[0]);
	v = rotationMatrix.transform3x3(rotationMatrix,v);
	v1 = ofxVec2f((v).x,(v).y);
	
	v2 = ofxVec2f(1,0);	
	v3 = ofxVec2f((projHandles[1]-projHandles[0]).x,(projHandles[1]-projHandles[0]).y);	
	float angle2 = v1.angle(v2);	
	
	[Prop(@"angle2") setFloatValue:angle2];
	
	rotationMatrix.makeRotationMatrix( PropF(@"angle1")*DEG_TO_RAD, ofxVec3f(0,1,0),
									  -PropF(@"angle2")*DEG_TO_RAD, ofxVec3f(0,0,1),
									  PropF(@"angle3")*DEG_TO_RAD, ofxVec3f(1,0,0));
	scale = 1.0/(points[1]-points[0]).length() ;
	
}

-(ofxPoint3f) convertWorldToFloor:(ofxPoint3f) p{
	p -= [self point3:0];	
	
	p = rotationMatrix.transform3x3(rotationMatrix,p);
	
	p.z *= -scale*([self projPoint:0] - [self projPoint:2]).length();
	p.x *= scale*([self projPoint:0] - [self projPoint:2]).length();
	
	p += ofxPoint3f([self projPoint:0].x, 0, [self projPoint:0].y);
	
	return p;
}

-(ofxPoint3f) convertWorldToProjection:(ofxPoint3f) p{
	ofxPoint2f p2 = [self convertWorldToFloor:p];
	return [([GetPlugin(Keystoner) getSurface:@"Floor" viewNumber:0 projectorNumber:0]) convertToProjection:p2];
}



-(ofxTrackedUser*) getDancer:(int)d{
	ofxTrackedUser* u = users.getUserWithId(dancers[d].userId);
	if(u != nil){
		return u;
	}
	return nil;	
}

-(IBAction) storeCalibration:(id)sender{
	int dancer;
	if(sender == storeA){
		dancer = 0;
	}
	if(sender == storeB){
		dancer = 1;
	}
	if(sender == storeC){
		dancer = 2;
	}
	
	vector<ofxTrackedUser*> vusers = users.getTrackedUsers(); 			
	for(int i=0;i<vusers.size();i++){
		bool matchingUser = NO;
		for(int j=0;j<3;j++){
			if(vusers[i]->id == dancers[j].userId){
				matchingUser = YES;
			}
		}
		if(!matchingUser){
			ofxTrackedUser * user = vusers[i];
			if(user->is_tracked){
				NSLog(@"Store calibration");
				XnStatus status = users.getXnUserGenerator().GetSkeletonCap().SaveCalibrationData(user->id,dancer);
				dancers[dancer].state = 2;
				dancers[dancer].userId = user->id;
			}
			break;	
		}
	}

	
	
}

-(void) controlMouseDragged:(float)x y:(float)y button:(int)button{
	if(draggedPoint != -1){
		ofxPoint2f mouse = ofPoint(2*x/640.0,2*y/480.0);
		
		if(draggedPoint <= 2){			
			xn::DepthMetaData dmd;
			depth.getXnDepthGenerator().GetMetaData(dmd);
			
			XnPoint3D pIn;
			pIn.X = mouse.x*640;
			pIn.Y = mouse.y*480;
			pIn.Z = dmd.Data()[(int)pIn.X+(int)pIn.Y*640];
			XnPoint3D pOut;
			
			depth.getXnDepthGenerator().ConvertProjectiveToRealWorld(1, &pIn, &pOut);
			ofxPoint3f coord = ofxPoint3f(pOut.X, pOut.Y, pOut.Z);
			[self setPoint3:draggedPoint coord:coord];
			[self setPoint2:draggedPoint coord:mouse];
		} else {
			mouse.y -= 1;
			float aspect = [self floorAspect];
			if(aspect < 1){
				mouse.x -= 0.5;
				mouse.x += aspect/2.0;
			} else {
				mouse.y -= 0.5;
				mouse.y += (1.0/aspect)/2.0;
				mouse *= 1.0/aspect;
			}
			
			[self setProjPoint:draggedPoint-3 coord:mouse];
			
			if(draggedPoint-3 <= 1){
				ofxVec2f v = [self projPoint:1] - [self projPoint:0];
				v = ofxVec2f(-v.y,v.x);
				
				[self setProjPoint:2 coord:[self projPoint:0]+v];
			}
		}
	}
	[self calculateMatrix];
}

-(void) controlMousePressed:(float)x y:(float)y button:(int)button{
	ofxPoint2f mouse = ofPoint(2*x/640,2*y/480);
	draggedPoint = -1;
	if(mouse.y <= 1){
		for(int i=0;i<3;i++){
			if (mouse.distance([self point2:i]) < 0.035) {
				draggedPoint = i;
			}
		}
	} else {
		mouse.y -= 1;	
		float aspect = [self floorAspect];
		if(aspect < 1){
			mouse.x -= 0.5;
			mouse.x += aspect/2.0;
		} else {
			mouse.y -= 0.5;
			mouse.y += (1.0/aspect)/2.0;
			mouse *= 1.0/aspect;
		}
		
		for(int i=0;i<2;i++){
			if (mouse.distance([self projPoint:i]) < 0.035) {
				draggedPoint = i+3;
			}
		}
	}
	NSLog(@"Mouse pressed %i  mouse: %fx%f",draggedPoint, mouse.x, mouse.y);
}

-(void) controlMouseReleased:(float)x y:(float)y{
	draggedPoint = -1;
}

-(float) floorAspect{
	return 	[[([GetPlugin(Keystoner) getSurface:@"Floor" viewNumber:0 projectorNumber:0]) aspect] floatValue];
}


-(ofxPoint3f) point3:(int)point{
	return ofxPoint3f([[customProperties valueForKey:[NSString stringWithFormat:@"point%ix",point]] floatValue], [[customProperties valueForKey:[NSString stringWithFormat:@"point%iy",point]] floatValue], [[customProperties valueForKey:[NSString stringWithFormat:@"point%iz",point]] floatValue]);
}
-(ofxPoint2f) point2:(int)point{
	return ofxPoint2f([[customProperties valueForKey:[NSString stringWithFormat:@"point%ia",point]] floatValue], [[customProperties valueForKey:[NSString stringWithFormat:@"point%ib",point]] floatValue]);
}
-(ofxPoint2f) projPoint:(int)point{
	return ofxPoint2f([[customProperties valueForKey:[NSString stringWithFormat:@"proj%ix",point]] floatValue], [[customProperties valueForKey:[NSString stringWithFormat:@"proj%iy",point]] floatValue]);
}

-(void) setPoint3:(int) point coord:(ofxPoint3f)coord{
	[customProperties setValue:[NSNumber numberWithFloat:coord.x] forKey:[NSString stringWithFormat:@"point%ix",point]];
	[customProperties setValue:[NSNumber numberWithFloat:coord.y] forKey:[NSString stringWithFormat:@"point%iy",point]];
	[customProperties setValue:[NSNumber numberWithFloat:coord.z] forKey:[NSString stringWithFormat:@"point%iz",point]];
}
-(void) setPoint2:(int) point coord:(ofxPoint2f)coord{
	[customProperties setValue:[NSNumber numberWithFloat:coord.x] forKey:[NSString stringWithFormat:@"point%ia",point]];
	[customProperties setValue:[NSNumber numberWithFloat:coord.y] forKey:[NSString stringWithFormat:@"point%ib",point]];
}
-(void) setProjPoint:(int) point coord:(ofxPoint2f)coord{
	[customProperties setValue:[NSNumber numberWithFloat:coord.x] forKey:[NSString stringWithFormat:@"proj%ix",point]];
	[customProperties setValue:[NSNumber numberWithFloat:coord.y] forKey:[NSString stringWithFormat:@"proj%iy",point]];
}

-(void) applicationWillTerminate:(NSNotification *)note{
	stop = true;
	context.getXnContext().Shutdown();
	/*delete &users;
	 delete &depth;
	 delete &context;*/
}
@end