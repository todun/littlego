// -----------------------------------------------------------------------------
// Copyright 2013 Patrick Näf (herzbube@herzbube.ch)
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



// -----------------------------------------------------------------------------
/// @brief The MainTabBarController class is the application window's root
/// view controller.
// -----------------------------------------------------------------------------
@interface MainTabBarController : UITabBarController <UITabBarControllerDelegate, UINavigationControllerDelegate>
{
}

- (UIViewController*) tabController:(enum TabType)tabID;
- (UIView*) tabView:(enum TabType)tabID;
- (void) activateTab:(enum TabType)tabID;
- (NSString*) resourceNameForTabType:(enum TabType)tabType;

@end
