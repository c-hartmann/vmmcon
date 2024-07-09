Create a VirtualBox Virtual Machine from ISO Image
or:
VMMCON - A Virtual Machine Manager Console / Controller
===

**A KDE Service Menu for Distro Hoppers**

---


What it does (in short)

It creates and runs a VirtualBox™ (VB) Virtual Machine (VM) from any optical
disc images by right clicking and selecting a new KDE Service Menu entry.
These DVD images *mostly* [^1] come in a `*.iso` container.

---

How it looks (a first view)

![Screenshot ISO image service menu opened][scr1]

---

What it does (in detail)

lorem ipsum babel ding

---


What it is made from / based on

* Desktop Entry Specification with KDE specifics
* Bourne Again Shell (bash)
* some icons (by u/walrusz)
* coffee


---

What it needs (to get running)

Download entire directory and place in:

    $HOME/.local/share/kservices5/

so you end up with this installation directory: (herein referred as $BD)

    $HOME/.local/share/kservices5/CreateVBoxVMfromISO

or download files (and helper dirs) individualy and place in:

    $HOME/.local/share/kservices5/ServiceMenus

Some more screens (dialogs)

![Screenshot ISO image service menu opened][scr1]
![Screenshot ISO image service menu opened][scr1]
![Screenshot ISO image service menu opened][scr1]
![Screenshot ISO image service menu opened][scr1]

---


extra install work (this is on icons)

place 'extra-icons' in appropriate subdirectories in:

    $HOME/.local/share/icons/hicolor/<size>/apps/

SVG icons go to (you might have to create the directory first):

    $HOME/.local/share/icons/hicolor/scalable/apps/

note sure on how to use this as an alternative (using size 128 as an example here):

    $ xdg-icon-resource install --novendor --size 128 --context apps --mode user <any>.png

for SVG icons this **might** work (omitting the size option):

    $ xdg-icon-resource install --novendor --context apps --mode user <any>.svg

hint: you might check your path(es) with this command:

    $ kf5-config --path icon

if you've done it right, you should be able to find your new icons in:

    $ kdialog --geticon Applications

---


What migth fail

Live isn't easy and so is this.
* the machine you like to create is already defined (by _this_ name you try to create)
* the dvd image has already been "registered" within VB

---



Technical stuff

### Files and directories explained (from within installation directory)
| File / Directory | Purpose |
| --- | --- |
| CreateVBoxVMfromISO.desktop | declaration of service menu extension |
| CreateVBoxVMfromISO.sh | the bash script, that does all the odd work |
| CreateVBoxVMfromISO.d/ | a directory for a bunch of helper files |
| ../icons.d/ | some icons used by the extension itself |
| ../distro-icons.d | icons used for VM list in VB (created by: u/walrusz) |
| ../templates.d/ | templates to be used with some specific VBoxManage arguments |
| ../distro-match-template.csv | a list of mappings from distro strings to templates |

---


### tweaks you might consider

consider using UEFI instead of BIOS for new VMs, as it gives you an initial screen size of 1024x768 instead of 800x600 with BIOS, that will nut fullfill the requirements of some Linux installers (e.g. kubuntu). You can do that in either MY_NAME.conf or MY_NAME.d/templates.d/BASE.conf.

The default icon is 'view-presentation-symbolic', that the freedesktop.org Icon Naming Specification, although the name does not perfectly fit in its meaning ;). But there might be a bunch of other nice icons in your host system, such as 'media-playback-playing', 'yast-bootloader', 'virtualbox' or 'display-and-tower', that comes with this package in MY_NAME.d/icons.d. The last one requires to be copied to $HOME/.local/share/icons/hicolor/apps/scalable/.

---


TODO
---
nicer icons
error handling (live isn't easy)
long options such as: --template --automatic --yes-to-all --power-up

---

License
---
![GPL v3](http://www.gnu.org/graphics/gplv3-127x51.png)

Copyright © 2022 Christian Hartmann

[^1]: other optical disc image such as RAW or DMG might work, but i havn't seen such and have no access to those things

[scr1]: ./wine.png "png icon wine"
