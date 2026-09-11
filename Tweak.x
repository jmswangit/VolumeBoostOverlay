#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <YouTubeHeader/MDCSlider.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/UIView+YouTube.h>
#import <YouTubeHeader/YTAlertView.h>
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/YTColorPalette.h>
#import <YouTubeHeader/YTCommonColorPalette.h>
#import <YouTubeHeader/YTCommonUtils.h>
#import <YouTubeHeader/YTLabel.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTQTMButton.h>

#define TweakKey @"VolumeBoostOverlay"

#define MIN_BOOST 0.0f
#define MAX_BOOST 20.0f
#define UNITY_BOOST 1.0f
#define BOOST_STEP 0.5f

static NSString *VolumeBoostUpdateNotification = @"VolumeBoostUpdateNotification";

static float currentBoost = 1.0f;
static NSString *currentBoostLabel = @"100%";

@interface YTMainAppControlsOverlayView (VolumeBoostOverlay)
- (void)didPressVolumeBoost:(id)arg;
- (void)updateVolumeBoostButton:(id)arg;
@end

@interface YTInlinePlayerBarContainerView (VolumeBoostOverlay)
- (void)didPressVolumeBoost:(id)arg;
- (void)updateVolumeBoostButton:(id)arg;
@end

@interface YTMainAppVideoPlayerOverlayViewController (VolumeBoostOverlay)
- (void)didPressVolumeBoost:(id)arg;
- (void)didChangeVolumeBoost:(MDCSlider *)s;
@end

#pragma mark - State

static NSString *VolumeBoostEnabledKey() {
    return [NSString stringWithFormat:@"YTVideoOverlay-%@-Enabled", TweakKey];
}

static BOOL VolumeBoostEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:VolumeBoostEnabledKey()];
}

static NSString *exactBoostLabel(float boost) {
    return [NSString stringWithFormat:@"%.0f%%", boost * 100.0f];
}

// Standard volume icon for the overlay button. Falls back to an SF Symbol if
// YouTube's own icon set does not contain the expected glyph.
static UIImage *VolumeBoostImage(BOOL muted) {
    UIColor *color = [%c(YTColor) white1];
    UIImage *image = [%c(QTMIcon) imageWithName:muted ? @"ic_volume_off" : @"ic_volume_up" color:color];
    if (image) {
        return image;
    }
    image = [%c(QTMIcon) imageWithName:muted ? @"ic_volume_mute" : @"ic_volume_up_filled" color:color];
    if (image) {
        return image;
    }
    if (@available(iOS 13.0, *)) {
        UIImage *symbol = [UIImage systemImageNamed:muted ? @"speaker.slash.fill" : @"speaker.wave.3.fill"];
        if (symbol) {
            return symbol;
        }
    }
    return nil;
}

#pragma mark - Audio

static NSHashTable *activeRenderers = nil;

static void RegisterRenderer(id renderer) {
    if (!activeRenderers) {
        activeRenderers = [NSHashTable weakObjectsHashTable];
    }
    if (renderer) {
        [activeRenderers addObject:renderer];
    }
}

static float GetLogarithmicAudioMultiplier() {
    float m = currentBoost;
    if (m <= UNITY_BOOST) {
        return m;
    }
    return powf(200.0f, (m - UNITY_BOOST) / (MAX_BOOST - UNITY_BOOST));
}

static void NotifyVolumeChange() {
    for (id renderer in [activeRenderers allObjects]) {
        if ([renderer respondsToSelector:@selector(setVolume:)]) {
            [renderer setVolume:1.0f];
        }
    }
}

static void SetBoost(float boost) {
    if (boost < MIN_BOOST) {
        boost = MIN_BOOST;
    }
    if (boost > MAX_BOOST) {
        boost = MAX_BOOST;
    }
    currentBoost = boost;
    currentBoostLabel = exactBoostLabel(boost);
    [[NSNotificationCenter defaultCenter] postNotificationName:VolumeBoostUpdateNotification object:nil];
    NotifyVolumeChange();
}

static void didSelectBoost(float boost) {
    SetBoost(boost);
}

%group AVFoundation

%hook AVPlayer

- (instancetype)init {
    id orig = %orig;
    RegisterRenderer(orig);
    return orig;
}

- (void)play {
    %orig;
    if (VolumeBoostEnabled()) {
        NotifyVolumeChange();
    }
}

- (void)setVolume:(float)volume {
    RegisterRenderer(self);
    if (VolumeBoostEnabled()) {
        volume = volume * GetLogarithmicAudioMultiplier();
    }
    %orig(volume);
}

%end

%hook AVAudioPlayerNode

- (instancetype)init {
    id orig = %orig;
    RegisterRenderer(orig);
    return orig;
}

- (void)setVolume:(float)volume {
    RegisterRenderer(self);
    if (VolumeBoostEnabled()) {
        volume = volume * GetLogarithmicAudioMultiplier();
    }
    %orig(volume);
}

%end

%hook AVAudioPlayer

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError {
    id orig = %orig;
    RegisterRenderer(orig);
    return orig;
}

- (instancetype)initWithData:(NSData *)data error:(NSError **)outError {
    id orig = %orig;
    RegisterRenderer(orig);
    return orig;
}

- (void)setVolume:(float)volume {
    RegisterRenderer(self);
    if (VolumeBoostEnabled()) {
        volume = volume * GetLogarithmicAudioMultiplier();
    }
    %orig(volume);
}

%end

%hook AVSampleBufferAudioRenderer

- (instancetype)init {
    id orig = %orig;
    RegisterRenderer(orig);
    return orig;
}

- (void)setVolume:(float)volume {
    RegisterRenderer(self);
    if (VolumeBoostEnabled()) {
        volume = volume * GetLogarithmicAudioMultiplier();
    }
    %orig(volume);
}

%end

%end

%group Top

%hook YTMainAppControlsOverlayView

- (id)initWithDelegate:(id)delegate {
    self = %orig;
    [self updateVolumeBoostButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateVolumeBoostButton:) name:VolumeBoostUpdateNotification object:nil];
    return self;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    [self updateVolumeBoostButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateVolumeBoostButton:) name:VolumeBoostUpdateNotification object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:VolumeBoostUpdateNotification object:nil];
    %orig;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    if ([tweakId isEqualToString:TweakKey]) {
        return VolumeBoostImage(currentBoost <= MIN_BOOST);
    }
    return %orig;
}

%new(v@:@)
- (void)updateVolumeBoostButton:(id)arg {
    YTQTMButton *button = self.overlayButtons[TweakKey];
    if (button) {
        [button setImage:VolumeBoostImage(currentBoost <= MIN_BOOST) forState:UIControlStateNormal];
    }
}

%new(v@:@)
- (void)didPressVolumeBoost:(id)arg {
    YTMainAppVideoPlayerOverlayViewController *c = [self valueForKey:@"_eventsDelegate"];
    [c didPressVolumeBoost:arg];
    [self updateVolumeBoostButton:nil];
}

%end

%end

%group Bottom

%hook YTInlinePlayerBarContainerView

- (id)init {
    self = %orig;
    [self updateVolumeBoostButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateVolumeBoostButton:) name:VolumeBoostUpdateNotification object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:VolumeBoostUpdateNotification object:nil];
    %orig;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    if ([tweakId isEqualToString:TweakKey]) {
        return VolumeBoostImage(currentBoost <= MIN_BOOST);
    }
    return %orig;
}

%new(v@:@)
- (void)updateVolumeBoostButton:(id)arg {
    YTQTMButton *button = self.overlayButtons[TweakKey];
    if (button) {
        [button setImage:VolumeBoostImage(currentBoost <= MIN_BOOST) forState:UIControlStateNormal];
    }
}

%new(v@:@)
- (void)didPressVolumeBoost:(id)arg {
    YTMainAppVideoPlayerOverlayViewController *c = [self.delegate valueForKey:@"_delegate"];
    [c didPressVolumeBoost:arg];
    [self updateVolumeBoostButton:nil];
}

%end

%end

%group Slider

@interface VolumeBoostSliderAlertView : YTAlertView
- (void)setupViews:(YTMainAppVideoPlayerOverlayViewController *)delegate sliderLabel:(NSString *)sliderLabel;
@end

%subclass VolumeBoostSliderAlertView : YTAlertView

%new(v@:@@)
- (void)setupViews:(YTMainAppVideoPlayerOverlayViewController *)delegate sliderLabel:(NSString *)sliderLabel {
    CGSize labelSize = CGSizeMake(50, 20);
    CGSize adjustButtonSize = CGSizeMake(30, 30);
    CGSize presetButtonSize = CGSizeMake(50, 30);

    MDCSlider *slider = [%c(MDCSlider) new];
    slider.statefulAPIEnabled = YES;
    slider.thumbHollowAtStart = NO;
    slider.minimumValue = MIN_BOOST;
    slider.maximumValue = MAX_BOOST;
    slider.value = currentBoost;
    slider.continuous = NO;
    slider.accessibilityLabel = sliderLabel;
    slider.tag = 'slid';
    [slider setTrackBackgroundColor:[%c(YTColor) grey3Alpha70] forState:UIControlStateNormal];

    YTLabel *minLabel = [%c(YTLabel) new];
    minLabel.text = exactBoostLabel(MIN_BOOST);
    minLabel.textAlignment = NSTextAlignmentLeft;
    minLabel.tag = 'minl';
    [minLabel yt_setSize:labelSize];
    [minLabel setTypeKind:22];

    YTLabel *maxLabel = [%c(YTLabel) new];
    maxLabel.text = exactBoostLabel(MAX_BOOST);
    maxLabel.textAlignment = NSTextAlignmentRight;
    maxLabel.tag = 'maxl';
    [maxLabel yt_setSize:labelSize];
    [maxLabel setTypeKind:22];

    YTLabel *currentValueLabel = [%c(YTLabel) new];
    currentValueLabel.text = currentBoostLabel;
    currentValueLabel.textAlignment = NSTextAlignmentCenter;
    currentValueLabel.tag = 'cvl0';
    [currentValueLabel yt_setSize:labelSize];
    [currentValueLabel setTypeKind:22];

    UIImage *minusImage = [%c(QTMIcon) imageWithName:@"ic_remove" color:nil];
    UIImage *plusImage = [%c(QTMIcon) imageWithName:@"ic_add" color:nil];
    BOOL legacy = minusImage == nil;
    if (legacy) {
        minusImage = [%c(QTMIcon) imageWithName:@"ic_remove_circle" color:nil];
        plusImage = [[%c(QTMIcon) imageWithName:@"ic_add_circle" color:nil] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    YTQTMButton *minusButton = [%c(YTQTMButton) buttonWithImage:minusImage accessibilityLabel:@"Decrease volume boost" accessibilityIdentifier:@"volume.boost.minus"];
    minusButton.flatButtonHasOpaqueBackground = !legacy;
    minusButton.sizeWithPaddingAndInsets = YES;
    minusButton.tag = 'mbtn';
    [minusButton yt_setSize:adjustButtonSize];
    [minusButton addTarget:delegate action:@selector(didPressMinusButton:) forControlEvents:UIControlEventTouchUpInside];

    YTQTMButton *plusButton = [%c(YTQTMButton) buttonWithImage:plusImage accessibilityLabel:@"Increase volume boost" accessibilityIdentifier:@"volume.boost.plus"];
    plusButton.flatButtonHasOpaqueBackground = !legacy;
    plusButton.sizeWithPaddingAndInsets = YES;
    plusButton.tag = 'pbtn';
    [plusButton yt_setSize:adjustButtonSize];
    [plusButton addTarget:delegate action:@selector(didPressPlusButton:) forControlEvents:UIControlEventTouchUpInside];

    struct {
        NSInteger tag;
        NSString *title;
    } presetBoostConfigs[] = {
        {'p100', @"100%"},
        {'p200', @"200%"},
        {'p500', @"500%"},
        {'p1k0', @"1K%"},
        {'p2k0', @"2K%"},
    };
    NSUInteger presetCount = sizeof(presetBoostConfigs) / sizeof(presetBoostConfigs[0]);

    NSMutableArray *presetButtons = [NSMutableArray arrayWithCapacity:presetCount];
    for (NSUInteger i = 0; i < presetCount; i++) {
        YTQTMButton *button = [%c(YTQTMButton) textButton];
        button.flatButtonHasOpaqueBackground = YES;
        button.sizeWithPaddingAndInsets = NO;
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        button.contentEdgeInsets = UIEdgeInsetsZero;
#pragma clang diagnostic pop
        button.tag = presetBoostConfigs[i].tag;
        [button yt_setSize:presetButtonSize];
        [button setTitleTypeKind:21];
        [button setTitle:presetBoostConfigs[i].title forState:UIControlStateNormal];
        [button addTarget:delegate action:@selector(didPressBoostPresetButton:) forControlEvents:UIControlEventTouchUpInside];
        [presetButtons addObject:button];
    }

    CGFloat contentWidth = [%c(YTCommonUtils) isIPad] ? 350 : 250;
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, contentWidth, 120)];
    [contentView addSubview:slider];
    [contentView addSubview:minLabel];
    [contentView addSubview:maxLabel];
    [contentView addSubview:currentValueLabel];
    [contentView addSubview:minusButton];
    [contentView addSubview:plusButton];
    for (YTQTMButton *button in presetButtons) {
        [contentView addSubview:button];
    }

    CGFloat sliderWidth = contentWidth - 80;
    slider.frame = CGRectMake(0, 0, sliderWidth, adjustButtonSize.height);
    slider.delegate = (id <MDCSliderDelegate>)contentView;
    [slider addTarget:delegate action:@selector(didChangeVolumeBoost:) forControlEvents:UIControlEventValueChanged];

    self.customContentView = contentView;
}

- (void)layoutSubviews {
    %orig;
    UIView *contentView = self.customContentView;
    YTLabel *minLabel = [contentView viewWithTag:'minl'];
    YTLabel *maxLabel = [contentView viewWithTag:'maxl'];
    YTLabel *currentValueLabel = [contentView viewWithTag:'cvl0'];
    YTQTMButton *minusButton = [contentView viewWithTag:'mbtn'];
    YTQTMButton *plusButton = [contentView viewWithTag:'pbtn'];
    MDCSlider *slider = [contentView viewWithTag:'slid'];

    NSMutableArray *presetButtons = [NSMutableArray array];
    NSInteger presetTags[] = {'p100', 'p200', 'p500', 'p1k0', 'p2k0'};
    for (int i = 0; i < 5; i++) {
        UIView *button = [contentView viewWithTag:presetTags[i]];
        if (button) [presetButtons addObject:button];
    }

    [slider alignCenterTopToCenterTopOfView:contentView paddingY:0];
    [minLabel alignTopLeadingToBottomLeadingOfView:slider paddingX:0 paddingY:10];
    [maxLabel alignTopTrailingToBottomTrailingOfView:slider paddingX:0 paddingY:10];
    [currentValueLabel alignCenterTopToCenterBottomOfView:slider paddingY:10];
    [minusButton alignCenterTrailingToCenterLeadingOfView:slider paddingX:10];
    [plusButton alignCenterLeadingToCenterTrailingOfView:slider paddingX:10];

    CGFloat padding = (contentView.frame.size.width - (50 * 5)) / 4;
    CGFloat buttonY = currentValueLabel.frame.origin.y + currentValueLabel.frame.size.height + 15;

    if ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft)
        presetButtons = (NSMutableArray *)[[presetButtons reverseObjectEnumerator] allObjects];
    for (int i = 0; i < presetButtons.count; ++i) {
        YTQTMButton *button = presetButtons[i];
        [button yt_setOrigin:CGPointMake(i * (padding + 50), buttonY)];
    }
}

- (void)pageStyleDidChange:(NSInteger)pageStyle {
    %orig;
    YTCommonColorPalette *colorPalette;
    Class YTCommonColorPaletteClass = %c(YTCommonColorPalette);
    if (YTCommonColorPaletteClass)
        colorPalette = pageStyle == 1 ? [YTCommonColorPaletteClass darkPalette] : [YTCommonColorPaletteClass lightPalette];
    else
        colorPalette = [%c(YTColorPalette) colorPaletteForPageStyle:pageStyle];
    UIView *contentView = self.customContentView;
    MDCSlider *slider = [contentView viewWithTag:'slid'];
    YTLabel *minLabel = [contentView viewWithTag:'minl'];
    YTLabel *maxLabel = [contentView viewWithTag:'maxl'];
    YTLabel *currentValueLabel = [contentView viewWithTag:'cvl0'];
    YTQTMButton *minusButton = [contentView viewWithTag:'mbtn'];
    YTQTMButton *plusButton = [contentView viewWithTag:'pbtn'];

    NSMutableArray *presetButtons = [NSMutableArray array];
    NSInteger presetTags[] = {'p100', 'p200', 'p500', 'p1k0', 'p2k0'};
    for (int i = 0; i < 5; ++i) {
        YTQTMButton *button = (YTQTMButton *)[contentView viewWithTag:presetTags[i]];
        if (button) [presetButtons addObject:button];
    }

    UIColor *textColor = [colorPalette textPrimary];
    UIColor *adjustButtonBackgroundColor = [UIColor colorWithWhite:pageStyle alpha:0.2];
    minLabel.textColor = textColor;
    maxLabel.textColor = textColor;
    currentValueLabel.textColor = textColor;
    minusButton.tintColor = textColor;
    minusButton.enabledBackgroundColor = adjustButtonBackgroundColor;
    plusButton.tintColor = textColor;
    plusButton.enabledBackgroundColor = adjustButtonBackgroundColor;

    for (YTQTMButton *button in presetButtons) {
        button.customTitleColor = textColor;
        button.enabledBackgroundColor = adjustButtonBackgroundColor;
    }

    [slider setThumbColor:textColor forState:UIControlStateNormal];
    [slider setTrackFillColor:textColor forState:UIControlStateNormal];
}

%end

VolumeBoostSliderAlertView *alert;

%hook YTMainAppVideoPlayerOverlayViewController

%new(v@:@)
- (void)didPressVolumeBoost:(id)arg {
    alert = [%c(VolumeBoostSliderAlertView) infoDialog];
    [alert setupViews:self sliderLabel:@"Volume boost"];
    alert.title = @"Volume boost";
    alert.shouldDismissOnBackgroundTap = YES;
    alert.customContentViewInsets = UIEdgeInsetsMake(8, 0, 0, 0);
    [alert show];
}

%new(v@:@)
- (void)didChangeVolumeBoost:(MDCSlider *)s {
    float boost = s.value;
    UILabel *currentValueLabel = [s.superview viewWithTag:'cvl0'];
    didSelectBoost(boost);
    currentValueLabel.text = currentBoostLabel;
}

%new(v@:@)
- (void)didPressMinusButton:(YTQTMButton *)button {
    MDCSlider *slider = [button.superview viewWithTag:'slid'];
    float newValue = MAX(slider.minimumValue, slider.value - BOOST_STEP);
    [slider setValue:newValue animated:YES];
    [self didChangeVolumeBoost:slider];
}

%new(v@:@)
- (void)didPressPlusButton:(YTQTMButton *)button {
    MDCSlider *slider = [button.superview viewWithTag:'slid'];
    float newValue = MIN(slider.maximumValue, slider.value + BOOST_STEP);
    [slider setValue:newValue animated:YES];
    [self didChangeVolumeBoost:slider];
}

%new(v@:@)
- (void)didPressBoostPresetButton:(YTQTMButton *)button {
    MDCSlider *slider = [button.superview viewWithTag:'slid'];
    float newValue = 1.0f;
    switch (button.tag) {
        case 'p100':
            newValue = 1.0f;
            break;
        case 'p200':
            newValue = 2.0f;
            break;
        case 'p500':
            newValue = 5.0f;
            break;
        case 'p1k0':
            newValue = 10.0f;
            break;
        case 'p2k0':
            newValue = 20.0f;
            break;
    }

    slider.value = newValue;
    [self didChangeVolumeBoost:slider];
    [alert dismiss];
    alert = nil;
}

%end

%end

%ctor {
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"Volume boost",
        SelectorKey: @"didPressVolumeBoost:",
        UpdateImageOnVisibleKey: @YES,
    });
    %init(AVFoundation);
    %init(Top);
    %init(Bottom);
    %init(Slider);
}
