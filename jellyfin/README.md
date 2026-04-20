# Jellyfin Plugin

A plugin that lets you search your Jellyfin media libraries and stream them directly in `mpv`.

## Requirements
- A running Jellyfin server
- `mpv` installed on your system

## Configuration
1. Open the plugin settings in Noctalia.
2. Provide your **Server URL** (e.g. `http://localhost:8096`).
3. Provide your **API Key** (Generated in Jellyfin Dashboard -> Advanced -> API Keys).
4. Optionally, provide your **User ID**. If left empty, it will use the first user available.

## Usage
Open the launcher and type `>jf ` followed by your search query (e.g., `>jf avatar`). Select the result to open it in `mpv`.
