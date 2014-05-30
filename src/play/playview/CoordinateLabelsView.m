// -----------------------------------------------------------------------------
// Copyright 2014 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// Project includes
#import "CoordinateLabelsView.h"
#import "layer/CoordinateLabelsLayerDelegate.h"
#import "../model/PlayViewMetrics.h"
#import "../model/PlayViewModel.h"
#import "../../go/GoGame.h"
#import "../../main/ApplicationDelegate.h"
#import "../../shared/LongRunningActionCounter.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for CoordinateLabelsView.
// -----------------------------------------------------------------------------
@interface CoordinateLabelsView()
@property(nonatomic, assign) PlayViewMetrics* playViewMetrics;
@property(nonatomic, retain) CoordinateLabelsLayerDelegate* layerDelegate;
@property(nonatomic, assign) bool updatesWereDelayed;
@end

@implementation CoordinateLabelsView

// -----------------------------------------------------------------------------
/// @brief Initializes a CoordinateLabelsView object that draws along the axis
/// @a axis.
///
/// @note This is the designated initializer of CoordinateLabelsView.
// -----------------------------------------------------------------------------
- (id) initWithAxis:(enum CoordinateLabelAxis)axis
{
  // Call designated initializer of superclass (UIView)
  self = [super initWithFrame:CGRectZero];
  if (! self)
    return nil;
  self.coordinateLabelAxis = axis;
  self.playViewMetrics = [ApplicationDelegate sharedDelegate].playViewMetrics;
  self.layerDelegate = [[[CoordinateLabelsLayerDelegate alloc] initWithMainView:self
                                                                        metrics:self.playViewMetrics
                                                                          model:[ApplicationDelegate sharedDelegate].playViewModel
                                                                           axis:axis] autorelease];
  [self.layer addSublayer:self.layerDelegate.layer];

  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(goGameDidCreate:) name:goGameDidCreate object:nil];
  [center addObserver:self selector:@selector(longRunningActionEnds:) name:longRunningActionEnds object:nil];
  [self.playViewMetrics addObserver:self forKeyPath:@"boardSize" options:0 context:NULL];
  [self.playViewMetrics addObserver:self forKeyPath:@"rect" options:0 context:NULL];
  [[ApplicationDelegate sharedDelegate].playViewModel addObserver:self forKeyPath:@"displayCoordinates" options:0 context:NULL];

  self.updatesWereDelayed = false;

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this PlayView object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self.playViewMetrics removeObserver:self forKeyPath:@"boardSize"];
  [self.playViewMetrics removeObserver:self forKeyPath:@"rect"];
  [[ApplicationDelegate sharedDelegate].playViewModel removeObserver:self forKeyPath:@"displayCoordinates"];
  self.playViewMetrics = nil;
  self.layerDelegate = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Internal helper that correctly handles delayed updates.
/// CoordinateLabelsView methods that need a view update should invoke this
/// helper instead of updateLayer().
///
/// If no long-running actions are in progress, this helper invokes
/// updateLayer(), thus triggering the update in UIKit.
///
/// If any long-running actions are in progress, this helper sets
/// @e updatesWereDelayed to true.
// -----------------------------------------------------------------------------
- (void) delayedUpdate
{
  if ([LongRunningActionCounter sharedCounter].counter > 0)
    self.updatesWereDelayed = true;
  else
    [self updateLayer];
}

// -----------------------------------------------------------------------------
/// @brief Notifies all layers that they need to update now if they are dirty.
/// This marks one update cycle.
// -----------------------------------------------------------------------------
- (void) updateLayer
{
  // No game -> no board -> no drawing. This situation exists right after the
  // application has launched and the initial game is created only after a
  // small delay.
  if (! [GoGame sharedGame])
    return;
  self.updatesWereDelayed = false;

  // Disabling animations here is essential for a smooth GUI update after a zoom
  // operation ends. If animations were enabled, setting the layer frames would
  // trigger an animation that looks like a "bounce". For details see
  // http://stackoverflow.com/questions/15370803/how-to-prevent-bounce-effect-when-a-custom-view-redraws-after-zooming
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  [self.layerDelegate drawLayer];
  [CATransaction commit];
}

// -----------------------------------------------------------------------------
/// @brief UIView method.
// -----------------------------------------------------------------------------
- (CGSize) intrinsicContentSize
{
  CGSize intrinsicContentSize;
  if (self.coordinateLabelAxis == CoordinateLabelAxisLetter)
  {
    intrinsicContentSize.width = self.playViewMetrics.rect.size.width;
    intrinsicContentSize.height = self.playViewMetrics.coordinateLabelStripWidth;
  }
  else
  {
    intrinsicContentSize.width = self.playViewMetrics.coordinateLabelStripWidth;
    intrinsicContentSize.height = self.playViewMetrics.rect.size.height;
  }
  return intrinsicContentSize;
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameDidCreate notification.
// -----------------------------------------------------------------------------
- (void) goGameDidCreate:(NSNotification*)notification
{
  // TODO xxx this should not be required; currently it *is* required because
  // during application launch the board size in PlayViewMetrics goes from
  // GoBoardSizeUndefined to a concrete size when the first GoGame is started;
  // while PlayViewMetrics has the board size as GoBoardSizeUndefined, the
  // PlayViewMetrics rect - and therefore our own intrinsic content size - is
  // zero
  [self invalidateIntrinsicContentSize];
  [self.layerDelegate notify:PVLDEventGoGameStarted eventInfo:nil];
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #longRunningActionEnds notification.
// -----------------------------------------------------------------------------
- (void) longRunningActionEnds:(NSNotification*)notification
{
  if (self.updatesWereDelayed)
    [self updateLayer];
}

// -----------------------------------------------------------------------------
/// @brief Responds to KVO notifications.
// -----------------------------------------------------------------------------
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  PlayViewModel* playViewModel = [ApplicationDelegate sharedDelegate].playViewModel;
  if (object == playViewModel)
  {
    if ([keyPath isEqualToString:@"displayCoordinates"])
    {
      [self.layerDelegate notify:PVLDEventDisplayCoordinatesChanged eventInfo:nil];
      [self delayedUpdate];
    }
  }
  else if (object == self.playViewMetrics)
  {
    if ([keyPath isEqualToString:@"rect"] || [keyPath isEqualToString:@"boardSize"])
    {
      // TODO xxx define a new dedicated event for board size changes; at the
      // moment we act as if the play view metrics rectangle changed, because
      // that is the only way how we can get all layers to update themselves.
      // but this also updates our own intrinsic size, which unnecessarily
      // affects a view layout cycle.

      // Notify Auto Layout that our intrinsic size changed. This provokes a
      // frame change.
      [self invalidateIntrinsicContentSize];
      [self.layerDelegate notify:PVLDEventRectangleChanged eventInfo:nil];
      // TODO xxx rename delayedUpdate and updateLayers to delayedDrawLayers and
      //      drawLayers
      [self delayedUpdate];
    }
  }
}

@end
