# Third-Party Audio

Downloaded: 2026-06-24

Source package:
- Name: Kenney Interface Sounds 1.0
- Source: https://kenney.nl/assets/interface-sounds
- Original archive: kenney_interface-sounds.zip
- License: Creative Commons Zero (CC0)
- License URL: https://creativecommons.org/publicdomain/zero/1.0/
- Author/distributor: Kenney, https://www.kenney.nl

Processing:
- Downloaded the original Kenney package into a temporary working directory.
- Selected nine short UI sounds from the original OGG files.
- Converted each selected file to CAF with macOS `afconvert`.
- Conversion format: `afconvert -f caff -d LEI16@44100 <source.ogg> <target.caf>`.
- No source ZIP or unused sounds are committed to the repository.

Bundled files:

| App file | Original file | Purpose | Duration | SHA-256 |
|---|---|---|---:|---|
| `break-start.caf` | `Audio/confirmation_002.ogg` | Eye break start | 0.539002s | `e678b47f69fd4f7372c49ba09617a10d90b4d9d28badfb7b41a0a39fd1f33717` |
| `break-start-soft.caf` | `Audio/confirmation_004.ogg` | Softer eye break start alternative | 0.490408s | `02483deaa27da6bbb2d76bb4bcdeae4a620b6464ade336d189225df62a48a384` |
| `break-start-open.caf` | `Audio/open_004.ogg` | Light open-style break start alternative | 0.322177s | `46ec2ec7f154d789b24e5bab9253be6c769472747a8e9718b6fadb4089e08cc7` |
| `focus-complete.caf` | `Audio/confirmation_001.ogg` | Pomodoro focus completion | 0.289841s | `5a2233232d000524ce55a4d3349a6efc19e284a1e0991e68983a9013495e3391` |
| `focus-complete-bright.caf` | `Audio/confirmation_003.ogg` | Brighter focus completion alternative | 0.320726s | `5127d68a3f6f8bec8f6a82cd9fbdf66fc380fbd9efd156bdf8885f505cd50908` |
| `focus-complete-soft.caf` | `Audio/open_002.ogg` | Softer focus completion alternative | 0.313469s | `e58e278ef335cb3e0ca17eea158012caca40a2134ce5b71957c802f687590325` |
| `break-complete.caf` | `Audio/select_003.ogg` | Break completion confirmation | 0.379864s | `b71ef80dc7cc8bea0a15faf4e36aaa4de0fae3e743819fef5c21add3f3754aa1` |
| `break-complete-crisp.caf` | `Audio/select_004.ogg` | Crisper break completion alternative | 0.379864s | `ffabc921fdebf764bd90d2af52556a1306a0e8fa4755062f603148f4de5cd425` |
| `break-complete-soft.caf` | `Audio/close_002.ogg` | Softer break completion alternative | 0.313787s | `c75c85abae0c486e0b5b579a0df6b27ab89af5f223d75b18d0a5d1b80dfd5a44` |
