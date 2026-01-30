# Kegel Trainer for Garmin Watches 🎯⌚

A simple, discreet Kegel exercise trainer app for Garmin smartwatches. Track your pelvic floor exercises with guided timing and vibration feedback.

## Features

- **10 repetitions** per session
- **10-second contraction** phases with countdown
- **5-second rest** phases between reps
- **Visual progress** arc showing time remaining
- **Vibration feedback** at phase transitions
- **Touch and button** support for starting/stopping
- Works on **round and square** displays

## Exercise Flow

1. **Start**: Press START button or tap screen
2. **Contract**: Hold for 10 seconds (red countdown)
3. **Relax**: Rest for 5 seconds (green countdown)
4. **Repeat**: 10 total repetitions
5. **Complete**: Celebration vibration pattern

Total workout time: ~2.5 minutes

## Supported Devices

- Fenix 6/6S/6 Pro Series
- Fenix 7/7S/7X Series
- Forerunner 245, 255, 265, 955, 965
- Venu 2/2S/2 Plus, Venu 3/3S
- Vivoactive 4/4S/5
- Instinct 2/2S/3
- Epix 2 Series

## Installation

### Prerequisites

1. **Garmin Connect IQ SDK** - Download from [developer.garmin.com](https://developer.garmin.com/connect-iq/sdk/)
2. **Visual Studio Code** with [Monkey C Extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c)
3. **Java 8+** (required by the SDK)
4. **Developer Key** - Generate with:
   ```bash
   openssl genrsa -out developer_key.der 4096
   ```

### Build & Deploy

#### Using VS Code (Recommended)

1. Open this folder in VS Code
2. Press `Ctrl+Shift+P` → "Monkey C: Build Current Project"
3. Select your target device
4. Press `F5` to run in simulator

#### Using Command Line

```bash
# Set your SDK path
export CIQ_HOME=~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-xxx

# Build for a specific device (e.g., fenix7)
monkeyc -d fenix7 \
    -f monkey.jungle \
    -o bin/KegelTrainer.prg \
    -y /path/to/developer_key.der

# Run in simulator
connectiq &
monkeydo bin/KegelTrainer.prg fenix7
```

#### Install on Watch

1. Build the release version:
   ```bash
   monkeyc -e -o KegelTrainer.iq \
       -f monkey.jungle \
       -y /path/to/developer_key.der
   ```
2. Connect your watch via USB
3. Copy `KegelTrainer.prg` to `GARMIN/APPS/` on your watch
4. Disconnect and find the app in your watch's app list

## Project Structure

```
kegel-trainer/
├── manifest.xml              # App configuration & supported devices
├── monkey.jungle             # Build configuration
├── source/
│   ├── KegelTrainerApp.mc    # Application entry point
│   ├── KegelTrainerView.mc   # Main UI and timer logic
│   └── KegelTrainerDelegate.mc # Button/touch input handling
└── resources/
    ├── drawables/
    │   ├── drawables.xml     # Drawable definitions
    │   └── launcher_icon.png # App icon
    └── strings/
        └── strings.xml       # Localized strings
```

## Customization

### Modify Exercise Parameters

Edit these constants in `KegelTrainerView.mc`:

```monkeyc
private const CONTRACT_TIME = 10;   // Contraction duration (seconds)
private const RELAX_TIME = 5;       // Rest duration (seconds)
private const TOTAL_REPS = 10;      // Number of repetitions
```

### Add More Devices

Edit `manifest.xml` and add product IDs:

```xml
<iq:product id="your_device_id"/>
```

Find device IDs in the [Garmin Device Reference](https://developer.garmin.com/connect-iq/compatible-devices/).

## Controls

| Input | Action |
|-------|--------|
| START button | Begin exercise / Restart |
| BACK button | Cancel (during exercise) / Exit (when idle) |
| Screen tap | Begin exercise (touchscreen devices) |

## Tips for Best Results

- Find a quiet moment for your exercises
- The vibration keeps it discreet - no one needs to know!
- Try to do 2-3 sessions per day for best results
- Focus on isolating the pelvic floor muscles
- Breathe normally throughout the exercise

## License

MIT License - Feel free to modify and share!

## Contributing

Improvements welcome! Feel free to:
- Add more exercise programs
- Improve the UI design
- Add settings/customization options
- Support additional languages

## Resources

- [Connect IQ Developer Guide](https://developer.garmin.com/connect-iq/)
- [Monkey C API Documentation](https://developer.garmin.com/connect-iq/api-docs/)
- [Garmin Developer Forums](https://forums.garmin.com/developer/connect-iq/)
