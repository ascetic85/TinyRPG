//
//  GameLayer.h
//  MiniRPG
//
//  Created by Brandon Trebitowski on 1/25/13.
//
//

#import <GameKit/GameKit.h>

// When you import this file, you import all the cocos2d classes
#import "cocos2d.h"

// HelloWorldLayer
@interface GameLayer : CCLayer

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) scene;

@end
