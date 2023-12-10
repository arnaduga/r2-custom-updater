# reMarkable 2 custom template updater

With a reMarkable 2 tablet, you can have some custom templates (unofficially). That is very great an useful!

However, everytime you get an official update, your custom templates are lost.

The goal of this script is to simplify reapplying your custom template settings, by uploading the images files and updating the `templates.json` file if the settings are gone (2 successive calls won't make duplications).

This script works only on `bash/zsh`, sorry Windows users...


BONUS
Eight O'RLY cover as custom templates!


## Pre-requisite

### (Recommended) Assign a fixed IP to your reMarkable 2 tablet

This step is absolutely optional, however, it makes it easy for future usages. 
On you router settings, assign a fixed address to your reMarkable 2 tablet, for instance `192.168.0.50`.

> **Warning**: some routers distribute addresses on a different range, like `192.168.1.x`. 
> 
> Please adjust according to your home network.

### Get your reMarkable 2 IP address and ssh password

There multiple websites and blog posts explaining how to retrieve the ip address and the password for SSH to the reMarkable tablet.

You can look at [here](https://philerb.com/2021/12/26/remarkable-tablet-ssh/) or [here](https://www.simplykyra.com/learn-how-to-access-your-remarkable-through-the-command-line/).

### Set a SSH key

The script (heavily) relays on `ssh` to access to your reMarkable tablet and adjust files.

There are 2 information required by the script to run: 
    - Tablet IP address (fixed IP if you follow the first recommendation)
    - SSH identity key (private key)

By default, there is no public/private key associated with your tablet, just a password.

To generate a new keypair (it is recommanded to not use an existing one), in a shell window, type the following commands: 

```bash
$ ssh-keygen -t rsa -b 2048 -C "remarkable2"
Generating public/private rsa key pair.
Enter file in which to save the key (/Users/arnaduga/.ssh/id_rsa): /Users/arnaduga/.ssh/remarkable2
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /Users/arnaduga/.ssh/remarkable2
Your public key has been saved in /Users/arnaduga/.ssh/remarkable2.pub
The key fingerprint is:
SHA256:vpmnCa4UytfCwOGT4f+EQ2SzXI12HxQF+/uMtmw9m9o reMarkable2
The key's randomart image is:
+---[RSA 2048]----+
|          ++.    |
|       o . .     |
|  o + + o o      |
| + B = . . o     |
|  B =   S . .    |
| . B + .     .   |
|  o O + .   ..   |
|   o * . =..o=o. |
|    ..o *o o=oEo |
+----[SHA256]-----+
```

> **Note**: the folder will differ, as hopefully your username is not `arnaduga`. Adujst accordingly.

Then, to copy your public key to the tablet (considering the table is ip `192.168.0.50`):

```bash
$ ssh-copy-id -i ~/.ssh/remarkable2 root@192.168.0.50
```

You will be asked for the SSH password.

That's it!

To test the SSH connection using the key, you can type `ssh -i ~/.ssh/remarkable2 root@192.168.0.50`


### Software pre-requisites

Only one major dependency is required by the script: `jq`, a standard tool to handle JSON file.

To check if `jq` is installed on your system, type `jq --version`. 

To install `jq`, please refer to your system. It could be `sudo apt install jq` or `sudo dnf install jq` or `brew install jq`...

In case you did not check the dependency before running the script, don't worry, you will be warned!

## Usage

### Prepare your templates

First of all, you have to prepare some template files. These can be `png` (bitmap) or `svg` (vector) image file.

For reference, and bootstrap, you can find in the `./originals` folder of this repo, the original files from a reMarkable 2 tablet. It can be very useful for the picture size.

You can store your templates in any folder you want. 

This repo includes some templates to be used as notebook covers, and the picture files are located in the `./templates/` folder.


### Prepare the custom reference

To let the script know what are the templates you want to add to your tablet, please create a dedicated `json` file, from `custom.json` model.

The structure of the file is: 

```javascript
{
    "templates": [
        {
            "name": "<template name>",
            "filename": "<template filename>",
            "iconCode": "<icon code>",
            "categories": [
                "<category>"
            ]
        }
        /* *** other templates definition *** */
    ]
}
```

where:
    - `<template name>` is the tempalte name, as display in the templates list
    - `<template filename>` is the template filename, without extension
    - `<icon code>` is the icon code. Unfortunately, we can note create new icon code. We have to use one of the existing one. Please look at `./originals/templates.json` file to find them
    - `<category>` is a category to classify the template. POssible values:   `Creative`, `Grids`, `Life/organize`, `Lines`


For instance, here is a `custom.json` file to manage 2 additionnal custom templates:
```javascript
{
    "templates": [
        {
            "name": "O'RLY - Squirrel",
            "filename": "ORLY-squirel",
            "iconCode": "\ue9fe",
            "categories": [
                "Creative"
            ]
        },
        {
            "name": "O'RLY - Pokemon",
            "filename": "ORLY-pokemon",
            "iconCode": "\ue9fe",
            "categories": [
                "Creative", 
                "Life/Organize"
            ]
        }
    ]
}
```


### Script options

Here the help of the script itself, for reference:
```bash
$ ./reMarkable-update.sh -h

----------=== reMarkable-update.sh - v1.0 ===----------

Source: https://github.com/arnaduga/r2-custom-updater
License: MIT

Script to update a reMarkable tablet with custome templates (after an update)

Usage: update.sh -r <IP_reMarkable> -i <SSH_identity_file> -t <template_folder> -c <custom_json_template_file>


  -r <ip_reMarkable.json>           MANDATORY   : IP of the reMarkable tablet
  -c <custom_json_template_file>    MANDATORY   : JSON file contains your custom template definition
  -i <SSH_identity_file>            MANDATORY   : the private key to connect to reMarkable tablet
  -t <template_folder>              MANDATORY   : template hosting all your custom template (png|svg)
  -d                                OPTIONAL    : Activate the debug log mode
  -h                                OPTIONAL    : Display THIS message

$
```

### Run the script

Considering all the previous information gathered (ip and identity file) and all the custom setup prepare (`custom.json` file and `*.png`/`*.svg` files), script runs like this, _after waking up your reMarkable tablet_:

```bash
$ ./reMarkable-update.sh -r 192.168.0.50 -i ~/.ssh/remarkable2 -c custom.json -t templates
[INFO ][2023-12-10-13:45:52] Pre-requisites checks...
[INFO ][2023-12-10-13:45:52] Checking dependencies
[LOG  ][2023-12-10-13:45:52] Starting update script
[INFO ][2023-12-10-13:45:52] Getting remote file (/usr/share/remarkable/templates/templates.json)
[INFO ][2023-12-10-13:46:28] Processing template name O'RLY - Squirrel
[INFO ][2023-12-10-13:46:28] Copying file to remote (templates/ORLY-squirel.png)
[INFO ][2023-12-10-13:46:29] Processing template name O'RLY - Pokemon
[INFO ][2023-12-10-13:46:29] Copying file to remote (templates/ORLY-pokemon.png)
[INFO ][2023-12-10-13:46:32] Processing template name O'RLY - Octopus
[INFO ][2023-12-10-13:46:32] Copying file to remote (templates/ORLY-octopus.png)
[INFO ][2023-12-10-13:46:33] Processing template name O'RLY - Llama
[INFO ][2023-12-10-13:46:33] Copying file to remote (templates/ORLY-llama.png)
[INFO ][2023-12-10-13:46:35] Processing template name O'RLY - Jabba
[INFO ][2023-12-10-13:46:35] Copying file to remote (templates/ORLY-jabba.png)
[INFO ][2023-12-10-13:46:36] Processing template name O'RLY - Hedgehog
[INFO ][2023-12-10-13:46:36] Copying file to remote (templates/ORLY-hedgehog.png)
[INFO ][2023-12-10-13:46:37] Processing template name O'RLY - Hamster
[INFO ][2023-12-10-13:46:37] Copying file to remote (templates/ORLY-hamster.png)
[INFO ][2023-12-10-13:46:39] Processing template name O'RLY - Hamster 2
[INFO ][2023-12-10-13:46:40] Copying file to remote (templates/ORLY-hamster-2.png)
[LOG  ][2023-12-10-13:46:41] In case of error, backup file is: backups/templates.json.2023-12-10-134641
[INFO ][2023-12-10-13:46:41] Copy files to remote
[INFO ][2023-12-10-13:46:41] Copying file to remote (templates.json)
[INFO ][2023-12-10-13:46:41] Restarting main reMarkable application (xochitl)
[LOG  ][2023-12-10-13:46:42] Update script done.

```

_That's all folks!_


## Limitations

Some limits and improvements are required. They are listed in the [repo issue tracker](https://github.com/arnaduga/r2-custom-updater/issues).


## Questions?

If you have some questions, bug reports or remarks, please use the [repo issue tracker](https://github.com/arnaduga/r2-custom-updater/issues).