# ARtillery

ARtillery is an augmented reality (AR) ballistic projectile game with destructible terrain and ludicrous weapons.

#### Pre-requisites

 * Xcode ([download](https://itunes.apple.com/us/app/xcode/id497799835?mt=12))
 * An ARKit capable iOS device.

#### Acquiring Source Code

1. Open Xcode
2. Open the "Source Control" menu.
3. Select "Clone..."
4. Where it asks for "Search or enter repository URL", enter `https://github.com/fra99le/TanksAR.git`
5. Click "Clone" button in the lower right corner.
6. Select a location.  The default of `~/Documents/TanksAR` is fine.

#### Compiling and Running

0. If the project if not open, use finder to navigate to the project file
(e.g.,&nbsp;`~/Documents/TanksAR/TanksAR.xcodeproj`) and
double click on it.  This should open the project in Xcode.
1. If "no scheme" is shown near the left end of the top of the Xcode window:
    1. Click on "no schemes".
    2. Select "New Scheme..."
    3. Select "TanksAR" for Target and "TanksAR" for the Name.
    4. Click OK.
2. Attach an ARKIt capable iOS device via USB.
3. If the iOS device asks "Trust This Computer?", select "Trust".
4. At the top of the Xcode, to the right of "TanksAR", click and select the
name of the iOS device to use.  It may take a few minutes for Xcode to prepare
the device and make it available.
5. Open the "Product" menu and click on "Profile".
6. Once "Instruments" app launches, find the newly installed ARtillery icon on
your device.
7. Tap the icon to launch ARtillery.
8. Tap "OK" when prompted `"ARtillery" Would like to Access the Camera".

