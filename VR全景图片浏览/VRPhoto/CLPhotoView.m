//
//  CLPhotoView.m
//  VR全景图片浏览
//
//  Created by tusm on 2017/3/5.
//  Copyright © 2017年 cleven. All rights reserved.
//

#import "Bridging-Header.h"
#import "CLPhotoView.h"

@interface CLPhotoView ()<GLKViewDelegate>
/// 相机广角角度
@property (nonatomic,assign)CGFloat overture;
/// 索引数
@property (nonatomic,assign)int numIndices;
/// 顶点索引缓存指针
@property (nonatomic,assign)GLuint vertexIndicesBufferID;
/// 顶点缓存指针
@property (nonatomic,assign)GLuint vertexBufferID;
/// 纹理缓存指针
@property (nonatomic,assign)GLuint vertexTexCoordID;
/// 着色器
@property (nonatomic,strong)GLKBaseEffect *effect;
/// 图片纹理信息
@property (nonatomic,strong)GLKTextureInfo *textureInfo;
/// 模型坐标系
@property (nonatomic,assign)GLKMatrix4 modelViewMatrix;
/// 拖拽手势
@property (nonatomic,assign)CGFloat panX;
@property (nonatomic,assign)CGFloat panY;
@property (nonatomic,assign)CGFloat sphereSliceNum;
///  球体半径
@property (nonatomic,assign)CGFloat sphereRadius;
@property (nonatomic,assign)CGFloat sphereScale;

@property (nonatomic,strong)CMMotionManager *motionManager;
@property (nonatomic,strong)UIPanGestureRecognizer *pan;


@end

@implementation CLPhotoView

-(CMMotionManager *)motionManager
{
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc]init];
        _motionManager.deviceMotionUpdateInterval = 1.0 / 60.0;//更新间隔
        _motionManager.showsDeviceMovementDisplay = YES;
    }
    return _motionManager;
}

-(UIPanGestureRecognizer *)pan
{
    if (!_pan) {
        _pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panActionDidClick:)];
    }
    return _pan;
}

-(instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.modelViewMatrix = GLKMatrix4Identity;
        self.sphereSliceNum = 200;
        self.sphereRadius = 1.0;
        self.sphereScale = 300;
        
        /// 初始化GLKView
        [self setupGLKView];
        /// 设置buffers
        [self setupBuffer];
        /// 检测屏幕位置(加速器与陀螺仪)
        [self startDeviceMotion];
        /// 添加拖拽手势
        [self addPanGestureRecognizer];
        
        [self addDisplayLink];
        
    }
    return self;
}


-(void)setPhotoURL:(NSString *)photoURL
{
    _photoURL = photoURL;
    
    [self runningTexture:photoURL];
}

-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    // 清除缓冲区的内容
    glClearColor(0, 0, 0, 1);
    // 清除颜色缓冲区与深度缓冲区内容
    glClear((GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT));
    // 渲染着色器
    [_effect prepareToDraw];

    glDrawElements((GL_TRIANGLES), (_numIndices),(GL_UNSIGNED_SHORT), nil);
    
    [self update];

}

- (void)update
{
    float aspect = fabs(self.bounds.size.width / self.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(85.0), aspect, 0.1, 400.0);
    projectionMatrix = GLKMatrix4Scale(projectionMatrix, -1.0, 1.0, 1.0);
    
    if (_motionManager.deviceMotion != nil){
        float w = _motionManager.deviceMotion.attitude.quaternion.w;
        float x = _motionManager.deviceMotion.attitude.quaternion.x;
        float y = _motionManager.deviceMotion.attitude.quaternion.y;
        float z = _motionManager.deviceMotion.attitude.quaternion.z;
        
        projectionMatrix = GLKMatrix4RotateX(projectionMatrix, -(0.005 * _panY));
        
        GLKQuaternion quaternion = GLKQuaternionMake(-x, y, z, w);
        GLKMatrix4 rotation = GLKMatrix4MakeWithQuaternion(quaternion);
        projectionMatrix = GLKMatrix4Multiply(projectionMatrix, rotation);
        
        /// 为了保证在水平放置手机的时候, 是从下往上看, 因此首先坐标系沿着x轴旋转90度
        projectionMatrix = GLKMatrix4RotateX(projectionMatrix, -(M_PI_2));
        _effect.transform.projectionMatrix = projectionMatrix;
    
        GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix,(0.005 * _panX));
        _effect.transform.modelviewMatrix = modelViewMatrix;
    }
}

- (void)setupGLKView
{
    /// 设置颜色格式和深度格式
    self.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    self.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    self.delegate = self;
    self.context = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    //将此“EAGLContext”实例设置为OpenGL的“当前激活”的“Context”
    [EAGLContext setCurrentContext:self.context];
    /// 注意: 激活深度检测,设置深度检测一定要放在设置上一句的下面, 要不然context还没有激活
    glEnable(GL_DEPTH_TEST);
    
}

- (void)setupBuffer
{
    float *vertices = 0;// 顶点
    float *texCoord = 0;// 纹理
    uint16_t *indices  = 0;// 索引
    int32_t numVertices = 0;

    /// 编译C文件 获取顶点/纹理/索引
    self.numIndices = initSphere(_sphereSliceNum, _sphereRadius, &vertices, &texCoord, &indices,  &numVertices);
    
    
    /// 加载顶点索引数据
    glGenBuffers(1, &_vertexIndicesBufferID); // 申请内存
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _vertexIndicesBufferID);// 将命名的缓冲对象绑定到指定的类型上去
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, _numIndices * sizeof(GLushort),indices, GL_STATIC_DRAW);
    
    /// 加载顶点坐标数据
    glGenBuffers(1, &_vertexBufferID);
    glBindBuffer((GL_ARRAY_BUFFER), _vertexBufferID);
    glBufferData((GL_ARRAY_BUFFER), (numVertices) * 3 * sizeof(GLfloat), vertices, (GL_STATIC_DRAW));
    
    /// 激活顶点位置属性
    glEnableVertexAttribArray(GLKVertexAttribPosition);

    glVertexAttribPointer(GLKVertexAttribPosition, 3, (GL_FLOAT), GL_FALSE, sizeof(GLfloat) * 3, nil);
    
    // 纹理
    glGenBuffers(1, &_vertexTexCoordID);
    glBindBuffer((GL_ARRAY_BUFFER), _vertexTexCoordID);
    glBufferData((GL_ARRAY_BUFFER),(numVertices) * 2 * sizeof(GLfloat), texCoord, (GL_DYNAMIC_DRAW));
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 2, nil);
    
}

- (void)startDeviceMotion
{
    /**设置初始坐标系, 并开始监控
     CMAttitudeReferenceFrameXArbitraryCorrectedZVertical: 描述的参考系默认设备平放(垂直于Z轴)，在X轴上取任意值。实际上当你开始刚开始对设备进行motion更新的时候X轴就被固定了。不过这里还使用了罗盘来对陀螺仪的测量数据做了误差修正
     使用pull形式获取数据
     */
    [self.motionManager startDeviceMotionUpdates];
    
    _modelViewMatrix = GLKMatrix4Identity;

    
}

- (void)addPanGestureRecognizer
{
    [self addGestureRecognizer:self.pan];
    
}

- (void)addDisplayLink
{
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayAction)];
    

    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}
- (void)runningTexture:(NSString *)photoUrl
{
    
    // 获取图片纹理信息
    NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithBool:YES],
                              GLKTextureLoaderOriginBottomLeft,
                              nil];
    
    self.textureInfo = [GLKTextureLoader textureWithContentsOfFile:photoUrl options:options error:nil];

    _effect = [GLKBaseEffect new];
    _effect.texture2d0.enabled = GL_TRUE;
    _effect.texture2d0.name = _textureInfo.name;

}

#pragma mark - 监听方法
- (void)panActionDidClick:(UIPanGestureRecognizer *)rec
{
    CGPoint point = [rec translationInView:rec.view];
    _panX += point.x;
    _panY += point.y;
    // 变换完后设置0
    [rec setTranslation:CGPointZero inView:rec.view];
}

- (void)displayAction
{
    [self display];
}
@end
