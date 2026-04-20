# Authenticator Plugin

A secure TOTP (2FA) authenticator plugin for Noctalia.

## Features
- **Bar Widget**: Adds a shield-lock icon to your bar.
- **Quick Access**: Clicking the widget opens a panel displaying your current 2FA codes with a live countdown timer.
- **Copy on Click**: Click any code to instantly copy it to your clipboard.
- **Secure Storage**: Uses Gnome Keyring (`secret-tool`) to securely store your 2FA secrets instead of keeping them in plain text.

## Requirements
- `secret-tool` must be installed (usually part of `libsecret-tools` or `gnome-keyring`).
- `wl-copy` for copying to the clipboard.
- `python3` for calculating the tokens.

## Configuration
Right-click the bar widget and select **Settings** to add your accounts and their base32 secrets.
