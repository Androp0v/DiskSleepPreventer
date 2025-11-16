#  DiskSleepPreventer

A small macOS Swift command line utility to keep a disk awake while the computer is in use.

## Usage

To use it, run the following command in the folder containing the executable:
```zsh
./disk-sleep-preventer --disks "MyDrive"
```
To see additional options, use `--help`.

## Build from source

Build it from source by doing:
```zsh
swift build -c release
```
You can use `--show-bin-path` to display where Swift exported the resulting executable:
```zsh
swift build -c release --show-bin-path
```
This doesn't build the binary again, it just displays the output path.

## Why?
I developed this small command line utility because my external hard drive enclosure (QNAP TR-004) is very aggressive at putting the disks to sleep and has a **30s** wake up time. This often meant needing to wait for half a minute for a disk that I was actively using to spin up again.

## How does it work?
This command line utility works by periodically reading an auto-generated hidden file from the root of the disk (`/Volumes/MyDrive/.DiskSleepPreventer`), using `F_NOCACHE` to avoid ready a copy of the file from the OS cache.
