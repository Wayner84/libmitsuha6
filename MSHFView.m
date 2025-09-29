#import "public/MSHFView.h"
#import <math.h>

@implementation MSHFView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [self initWithFrame:frame audioSource:[[MSHFAudioSource alloc] init]];
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame audioSource:(MSHFAudioSource *)audioSource {
    self = [super initWithFrame:frame];
    
    if (self) {
        _numberOfPoints = 8;
        self.userInteractionEnabled = NO;
        self.gain = 50;
        self.sensitivity = 1;
        [self setAlpha:0.0f];
        
        self.audioSource = audioSource;
        self.audioSource.delegate = self;
        
        self.audioProcessing = [[MSHFAudioProcessing alloc] initWithBufferSize:1024];
        self.audioProcessing.delegate = self;
        
        [self initializeWaveLayers];
        self.points = (CGPoint *)malloc(sizeof(CGPoint) * _numberOfPoints);
    }
    
    return self;
}

-(void)dealloc {
    [_displayLink invalidate];
    free(self.points);
}

- (void)setNumberOfPoints:(NSInteger)numberOfPoints {
    if (_numberOfPoints != numberOfPoints) {
        free(self.points);
        self.points = (CGPoint *)malloc(sizeof(CGPoint) * numberOfPoints);
        _numberOfPoints = numberOfPoints;
    }
}

- (void)stop {
    if (self.audioSource.isRunning && !self.disableBatterySaver) {
        [self.audioSource stop];
        [self.displayLink setPaused:true];
        silentSince = -2;
        [self redraw];
    }
}

- (void)start {
    SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];
    
    if (!mediaController || [mediaController isPlaying]) {
        [self.audioSource start];
        [self.displayLink setPaused:false];
    }
}

- (void)initializeWaveLayers {
}

- (void)resetWaveLayers {
}

- (void)configureDisplayLink {
  self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(redraw)];

  [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  [self.displayLink setPaused:true];
}

- (void)updateWaveColor:(CGColorRef)waveColor subwaveColor:(CGColorRef)subwaveColor {
}

- (void)updateWaveColor:(CGColorRef)waveColor subwaveColor:(CGColorRef)subwaveColor subSubwaveColor:(CGColorRef)subSubwaveColor {
}

- (void)redraw {
    if (silentSince < ((long long)[NSDate timeIntervalSinceReferenceDate] - 1)) {
        if (!MSHFHidden) {
            MSHFHidden = true;
            [UIView animateWithDuration:0.5 animations:^{
                [self setAlpha:0.0f];
            }];
        }
    } else if (MSHFHidden) {
        MSHFHidden = false;
        [UIView animateWithDuration:0.5 animations:^{
            [self setAlpha:1.0f];
        }];
    }
}

- (void)updateBuffer:(float *)bufferData withLength:(int)length {
    for (int i = 0; i < length / 4; i++) {
        if (bufferData[i] > 0.000005) {
            silentSince = (long long)[NSDate timeIntervalSinceReferenceDate];
            break;
        }
    }
    
    [self.audioProcessing process:bufferData withLength:length];
}

- (void)layoutSubviews {
    float const pixelFixer = self.bounds.size.width / _numberOfPoints;
    for (int i = 0; i < _numberOfPoints; i++) {
        _points[i].x = i * pixelFixer;
    }
}

- (void)setSampleData:(float *)data length:(int)length {
    if (_numberOfPoints <= 0) {
        return;
    }

    if (length <= 0) {
        float const fillValue = _waveOffset;
        for (NSInteger i = 0; i < _numberOfPoints; i++) {
            _points[i].y = fillValue;
        }
        return;
    }

    NSUInteger const compressionRate = MAX((NSUInteger)1, (NSUInteger)length / (NSUInteger)_numberOfPoints);

    NSUInteger const availableSamples = (NSUInteger)length / compressionRate;
    NSUInteger const pointsToProcess = MIN((NSUInteger)_numberOfPoints, availableSamples);

    float gainAdjusted = self.gain * self.sensitivity;
    if (length == 480 && pointsToProcess > 0) {
        float meanLevel = 0.0f;
        vDSP_measqv(data, compressionRate, &meanLevel, pointsToProcess);
        gainAdjusted *= 256 * (meanLevel + 1);
    }

    BOOL const applyLimiter = (_limiter != 0.0f);
    float const upperBound = _limiter;
    float const lowerBound = -upperBound;

    BOOL const applyOffset = (_waveOffset != 0.0f);
    float const waveOffset = _waveOffset;

    for (NSUInteger i = 0; i < pointsToProcess; i++) {
        float sample = data[i * compressionRate] * gainAdjusted;
        if (applyLimiter) {
            sample = fminf(fmaxf(sample, lowerBound), upperBound);
        }
        if (applyOffset) {
            sample += waveOffset;
        }
        _points[i].y = sample;
    }

    float const fillValue = applyOffset ? waveOffset : 0.0f;
    for (NSUInteger i = pointsToProcess; i < (NSUInteger)_numberOfPoints; i++) {
        _points[i].y = fillValue;
    }
}
@end
