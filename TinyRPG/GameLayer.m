//
//  GameLayer.m
//  MiniRPG
//
//  Created by Brandon Trebitowski on 1/25/13.
//
//

#import "GameLayer.h"

// Import the interfaces
#import "GameLayer.h"
#import "config.h"

#import "CCAnimate+SequenceLoader.h"
#import "CCAnimation+SequenceLoader.h"

@interface GameLayer ()
@property(nonatomic, strong) CCTMXTiledMap *tileMap;
@property(nonatomic, strong) CCSprite *hero;
@property (nonatomic, strong) CCTMXLayer *metaLayer;
@property(nonatomic) BOOL canWalk;
@property(nonatomic) float tileSize;

@end


// HelloWorldLayer implementation
@implementation GameLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	GameLayer *layer = [GameLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

// on "init" you need to initialize your instance
-(id) init
{
	if( (self=[super init]) ) {
        
        // start in the room always
        NSString *filename = [NSString stringWithFormat:kStartingRoom];
        [self loadMapNamed:filename];
        
        // Load character sprite sheet frames into cache for hero
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"character.plist"];
        self.hero = [CCSprite spriteWithSpriteFrameName:@"male_walkcycle_s_01.png"];
        self.hero.position = ccp(32*6 + 16,64+16);
        self.hero.scale = 1;
        self.hero.anchorPoint = ccp(0.5,0.5);
        self.hero.zOrder = 0;
        [self addChild:self.hero z:[[self.tileMap layerNamed:@"floor"] zOrder]];
        
        // Enable touches
        CCDirector *director = [CCDirector sharedDirector];
        [[director touchDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
        
        self.canWalk = YES;
        
        [self schedule:@selector(update:)];
        
	}
	return self;
}

/**
 * Loads a tilemap from the bundle path with a given name.
 *
 */
- (void) loadMapNamed:(NSString *) name
{
    if(self.tileMap)
    {
        [self.tileMap removeAllChildrenWithCleanup:YES];
        [self removeChild:self.tileMap cleanup:YES];
        self.tileMap = nil;
    }
    name = [name stringByAppendingString:@".tmx"];
    self.tileMap = [CCTMXTiledMap tiledMapWithTMXFile:name];
    self.tileMap.anchorPoint = ccp(0,0);
    [self.tileMap setScale:kGameScale];
    [self addChild:self.tileMap z:-1];
    self.metaLayer = [self.tileMap layerNamed:@"meta"];   
    self.metaLayer.visible = NO;    
    self.tileSize = self.tileMap.tileSize.width;
    
}

/**
 * Keeps the viewpoint centered as the hero is walking
 */
- (void)update:(ccTime)dt
{
    [self setViewpointCenter:self.hero.position];
}

/**
 * Centers the view on our character.  If the character is near the edge
 * of the map, the view won't change.  Only the character will move.
 *
 */
-(void)setViewpointCenter:(CGPoint) position {
    
    CGSize winSize = [[CCDirector sharedDirector] winSize];
    
    int x = MAX(position.x, winSize.width / 2);
    int y = MAX(position.y, winSize.height / 2);
    x = MIN(x, (_tileMap.mapSize.width * _tileMap.tileSize.width)
            - winSize.width / 2);
    y = MIN(y, (_tileMap.mapSize.height * _tileMap.tileSize.height)
            - winSize.height/2);
    CGPoint actualPosition = ccp(x, y);
    
    CGPoint centerOfView = ccp(winSize.width/2, winSize.height/2);
    CGPoint viewPoint = ccpSub(centerOfView, actualPosition);
    self.position = viewPoint;
    
}

/**
 * Allow touches
 */
-(BOOL) ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event
{
	return YES;
}

/**
 * Moves the player to a given position. Also performs collision detection
 * against the meta layer for tiles with the property "Collidable" set
 * to true.
 *
 * If the player encounters an NPC or an item, they are no permitted to move
 * and the logic is handed off to the NPCManager to execut the related lua
 * script.
 */
-(void)setPlayerPosition:(CGPoint)position {
    
    if(!self.canWalk) return;
    
	CGPoint tileCoord = [self tileCoordForPosition:position];
    
    // Check walls
    int tileGid = [self.metaLayer tileGIDAt:tileCoord];
    if (tileGid) {
        NSDictionary *properties = [self.tileMap propertiesForGID:tileGid];
        if (properties) {
            NSString *collision = [properties valueForKey:@"collidable"];
            if (collision && [collision compare:@"true"] == NSOrderedSame) {
                return;
            }
        }
    }
    
    self.canWalk = NO;
    
    // Animate the player
    id moveAction = [CCMoveTo actionWithDuration:0.4 position:position];
    
	// Play actions
    [self playHeroMoveAnimationFromPosition:self.hero.position toPosition:position];
    [self.hero runAction:[CCSequence actions:moveAction, nil]];
    self.hero.position = position;
}

/**
 * Animates the player from one position to the next
 */
- (void) playHeroMoveAnimationFromPosition:(CGPoint) fromPosition toPosition:(CGPoint) toPosition
{
    NSString *direction = @"n";
    if(toPosition.x > fromPosition.x)
        direction = @"e";
    else if(toPosition.x < fromPosition.x)
        direction = @"w";
    else if(toPosition.y < fromPosition.y)
        direction = @"s";
    
    NSString *walkCycle = [NSString stringWithFormat:@"male_walkcycle_%@_%%02d.png",direction];
    CCActionInterval *action = [CCAnimate actionWithSpriteSequence:walkCycle numFrames:9 delay:.05 restoreOriginalFrame:YES];
    CCAction *doneAction = [CCCallFuncN actionWithTarget:self selector:@selector(heroIsDoneWalking)];
    [self.hero runAction:[CCSequence actions:action,doneAction, nil]];
}

/**
 * Called after the hero is done with his walk sequence
 */
- (void) heroIsDoneWalking
{
    self.canWalk = YES;
}

/**
 * Invokes player movement or dissmisal of the chat window.
 */
-(void) ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event
{
    
    CGPoint touchLocation = [touch locationInView: [touch view]];
    touchLocation = [[CCDirector sharedDirector] convertToGL: touchLocation];
    touchLocation = [self convertToNodeSpace:touchLocation];
    // todo: figure out touch location
    CGPoint playerPos = self.hero.position;
    CGPoint diff = ccpSub(touchLocation, playerPos);
    if (abs(diff.x) > abs(diff.y)) {
        if (diff.x > 0) {
            playerPos.x += _tileMap.tileSize.width;
        } else {
            playerPos.x -= _tileMap.tileSize.width;
        }
    } else {
        if (diff.y > 0) {
            playerPos.y += _tileMap.tileSize.height;
        } else {
            playerPos.y -= _tileMap.tileSize.height;
        }
    }
    
    if (playerPos.x <= (_tileMap.mapSize.width * _tileMap.tileSize.width) &&
        playerPos.y <= (_tileMap.mapSize.height * _tileMap.tileSize.height) &&
        playerPos.y >= 0 &&
        playerPos.x >= 0 )
    {
        [self setPlayerPosition:playerPos];
    }
    
}

/**
 * Given a point on the map, returns the tile coordinate for that point.
 */
- (CGPoint)tileCoordForPosition:(CGPoint)position {
    int x = position.x / (_tileMap.tileSize.width);
    int y = ((_tileMap.mapSize.height * _tileMap.tileSize.height) - position.y) / (_tileMap.tileSize.height);
    return ccp(x, y);
}

/**
 * Given a tile coordinate, returns the position on screen
 */
- (CGPoint)positionForTileCoord:(CGPoint)tileCoord {
    int x = (tileCoord.x * _tileMap.tileSize.width) + _tileMap.tileSize.width;
    int y = (_tileMap.mapSize.height * _tileMap.tileSize.height) - (tileCoord.y * _tileMap.tileSize.height) - _tileMap.tileSize.height;
    return ccp(x, y);
}

@end
