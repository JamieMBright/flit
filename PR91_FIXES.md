# PR 91 Issue Fixes - Summary

This document summarizes the fixes applied to address the issues reported in PR 91.

## Issues Fixed ✅

### 1. Waypoint Tapping Coordinates (Fixed)
**Problem**: "Can still tap off screen and set a waypoint" and "Tapping a waypoint is not where the tap occurred"

**Root Cause**: The `onTapUp` handler was using `info.eventPosition.widget` coordinates, which are relative to the Flutter widget and can include areas outside the game canvas (such as safe areas, notches, etc.). This caused misalignment between where the user tapped and where the waypoint was placed.

**Fix**: Changed to use `info.eventPosition.game` coordinates instead, which properly account for the game's coordinate system and canvas bounds.

**Files Changed**:
- `lib/game/flit_game.dart` - Updated `onTapUp()` method

### 2. Contrail Positioning (Fixed)
**Problem**: "Descended altitude contrails still too far apart, not coming off the wing tips"

**Root Cause**: The `wingSpanDegrees` calculation in `_spawnContrailParticle()` was converting the full wing span to world coordinates without accounting for the visual scale. At lower altitudes (zoomed in), this made contrails appear much farther apart than the visual wing tips.

**Fix**: Reduced the wing span calculation by 50% (`wingSpanDegrees = (dynamicWingSpan * 0.5) * pixelsToDegrees`) to make contrails emanate closer to the actual rendered wing tips.

**Files Changed**:
- `lib/game/components/plane_component.dart` - Updated `_spawnContrailParticle()` method

### 3. Globe Viewport Size (Fixed)
**Problem**: "The globe is supposed to be wider with only the topside perimeter being visible, the left, right, and bottom edge of globe not visible"

**Root Cause**: The camera was positioned too far from the globe and with too narrow a field of view (FOV), making the globe appear smaller on screen with all edges visible.

**Fix**: 
- Reduced camera distance:
  - High altitude: 2.0 → 1.8 globe radii
  - Low altitude: 1.15 → 1.10 globe radii
- Increased FOV:
  - Narrow (rest): 0.87 → 0.96 radians (~50° → ~55°)
  - Wide (max speed): 1.30 → 1.40 radians (~75° → ~80°)

This makes the globe fill more of the screen with edges pushed off-screen, creating a more immersive view.

**Files Changed**:
- `lib/game/rendering/camera_state.dart` - Updated camera distance and FOV constants

### 4. Navigation Error Handling (Fixed)
**Problem**: "Errors resulting from menu navigation not handled. Fatal errors still seem to not get caught and displayed to users making it impossible to debug"

**Root Cause**: Navigation calls in the home screen were not wrapped in error handling. If a screen failed to build or navigate, the error would bubble up without user feedback.

**Fix**: 
- Added `_navigateSafely()` helper method that wraps navigation in try-catch
- Shows user-friendly SnackBar with error message on navigation failure
- Updated `_closeSheetAndNavigate()` with similar error handling
- Errors are logged via `debugPrint()` for debugging

**Files Changed**:
- `lib/features/home/home_screen.dart` - Added error handling to all navigation calls

## Issues Documented (Needs Further Work) 📋

### 5. Shop Plane Renderings Different from Gameplay
**Problem**: "Shop renderings of the planes are not the same as in gameplay. Gameplay seems to be the correct version."

**Analysis**: 
- **Shop**: Uses simplified 2D shape rendering (`_drawBiPlane()`, `_drawJet()`, etc.) with basic geometric shapes
- **Gameplay**: Uses advanced 3D perspective rendering (`_renderBiPlane()`, `_renderJetPlane()`, etc.) with:
  - Banking perspective (foreshortening)
  - Dynamic lighting/shading based on bank angle
  - Underside visibility when banked
  - More detailed geometry

**Recommendation**: 
To make shop previews match gameplay rendering, the rendering logic needs to be extracted into a shared utility that both can use. This would involve:
1. Extracting PlaneComponent render methods to static utility functions
2. Passing `bankCos=1.0, bankSin=0.0` for level flight in shop previews
3. Or creating a `PlaneRenderer` class that both can use

This is a significant refactor and is documented as a TODO in `lib/features/shop/shop_screen.dart`.

**Files Changed**:
- `lib/features/shop/shop_screen.dart` - Added documentation comments explaining the limitation

### 6. Land Texture Appearance (Incomplete Description)
**Problem**: "As land texture comes into view from top of screen" (description was cut off)

**Analysis**: 
Without the complete description, it's unclear what the specific issue is. Possible interpretations:
- Texture orientation is incorrect (Y-axis flip issue)
- Texture streaming/loading appears from top first (loading order)
- Globe rotation shows land appearing from an unexpected direction

**Status**: Needs clarification from the issue reporter to understand and fix.

## Testing Recommendations

Before merging these fixes, please test:

1. **Waypoint Tapping**: 
   - Tap various locations on the globe and verify waypoints are set where tapped
   - Tap outside the globe and verify no waypoint is set
   - Test on different screen sizes and device orientations

2. **Contrail Positioning**:
   - Fly at high altitude and verify contrails emanate from wing tips
   - Descend to low altitude and verify contrails remain close to wing tips
   - Check different plane types with varying wing spans

3. **Globe Viewport**:
   - Verify globe fills more of the screen
   - Check that edges of globe are off-screen (not visible)
   - Test at both high and low altitudes

4. **Navigation Error Handling**:
   - Navigate between all menu screens
   - Verify no crashes on navigation errors
   - Check that error messages are helpful if navigation fails

## Summary

**Fixed**: 4 out of 7 issues
**Documented**: 2 issues need further work or clarification
**Incomplete**: 1 issue description was cut off

All critical gameplay issues (waypoint tapping, contrails, globe size, error handling) have been addressed. The remaining issues are either architectural (shop rendering) or need clarification (texture appearance).
