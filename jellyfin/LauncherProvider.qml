import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null
    property string name: "Jellyfin"
    property var launcher: null
    property bool handleSearch: true
    property bool supportsAutoPaste: false
    property string supportedLayouts: "both"

    // Search state
    property var searchResults: []
    property string currentSearchText: ""
    property bool isSearching: false
    property string lastQuery: ""

    // Settings
    property string serverUrl: pluginApi?.pluginSettings?.serverUrl || ""
    property string apiKey: pluginApi?.pluginSettings?.apiKey || ""
    property string userId: pluginApi?.pluginSettings?.userId || ""

    Timer {
        id: debounceTimer
        interval: 400
        repeat: false
        onTriggered: {
            root.performSearch(root.currentSearchText)
        }
    }

    function init() {
        Logger.i("JellyfinProvider", "init called");
        if (!userId && apiKey && serverUrl) {
            fetchUserId();
        }
    }

    function onOpened() {
        supportedLayouts = "list";
        // Reload settings if they changed while the launcher was closed
        serverUrl = pluginApi?.pluginSettings?.serverUrl || "";
        apiKey = pluginApi?.pluginSettings?.apiKey || "";
        userId = pluginApi?.pluginSettings?.userId || "";
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">jf ");
    }

    function commands() {
        return [{
            "name": ">jf",
            "description": "Search your Jellyfin library",
            "icon": "movie",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function() {
                launcher.setSearchText(">jf ");
            }
        }];
    }

    function getResults(searchText) {
        if (!searchText.startsWith(">jf ")) return [];

        let query = searchText.slice(4).trim();
        if (query.length === 0) return [];

        if (query !== lastQuery) {
            lastQuery = query;
            currentSearchText = query;
            debounceTimer.restart();
        }

        if (isSearching) {
            return [{
                "name": "Searching...",
                "description": "Querying Jellyfin server...",
                "icon": "refresh",
                "isTablerIcon": true,
                "isImage": false,
                "onActivate": function() {}
            }];
        }

        return searchResults;
    }

    function fetchUserId() {
        let url = serverUrl + "/Users";
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Authorization", 'MediaBrowser Token="' + apiKey + '"');
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        let users = JSON.parse(xhr.responseText);
                        if (users && users.length > 0) {
                            userId = users[0].Id;
                            Logger.i("JellyfinProvider", "Auto-detected User ID: " + userId);
                        }
                    } catch (e) {
                        Logger.e("JellyfinProvider", "Failed to parse users");
                    }
                }
            }
        };
        xhr.send();
    }

    function performSearch(query) {
        if (!serverUrl || !apiKey) {
            searchResults = [{
                "name": "Missing Configuration",
                "description": "Please configure Server URL and API Key in plugin settings.",
                "icon": "alert-circle",
                "isTablerIcon": true,
                "isImage": false,
                "onActivate": function() {}
            }];
            if (launcher) launcher.updateResults();
            return;
        }

        isSearching = true;
        if (launcher) launcher.updateResults();

        let searchEndpoint = userId ? "/Users/" + userId + "/Items" : "/Items";
        let url = serverUrl + searchEndpoint + "?SearchTerm=" + encodeURIComponent(query) + "&Recursive=true&IncludeItemTypes=Movie,Episode&Limit=20";

        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Authorization", 'MediaBrowser Token="' + apiKey + '"');
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isSearching = false;
                if (xhr.status === 200) {
                    try {
                        let response = JSON.parse(xhr.responseText);
                        let items = response.Items || [];
                        searchResults = items.map(item => formatEntry(item));
                        
                        if (searchResults.length === 0) {
                            searchResults = [{
                                "name": "No results",
                                "description": "No media found for '" + query + "'",
                                "icon": "info-circle",
                                "isTablerIcon": true,
                                "isImage": false,
                                "onActivate": function() {}
                            }];
                        }
                    } catch (e) {
                        searchResults = [{
                            "name": "Error",
                            "description": "Failed to parse search results.",
                            "icon": "alert-circle",
                            "isTablerIcon": true,
                            "isImage": false,
                            "onActivate": function() {}
                        }];
                    }
                } else {
                    searchResults = [{
                        "name": "Connection Error",
                        "description": "Could not connect to Jellyfin. HTTP Status: " + xhr.status,
                        "icon": "alert-circle",
                        "isTablerIcon": true,
                        "isImage": false,
                        "onActivate": function() {}
                    }];
                }
                if (launcher) launcher.updateResults();
            }
        };
        xhr.send();
    }

    function formatEntry(item) {
        let title = item.Name;
        let desc = "";
        if (item.Type === "Episode") {
            desc = "Episode";
            if (item.SeriesName) desc = item.SeriesName + " - " + desc;
        } else {
            desc = item.ProductionYear ? item.ProductionYear.toString() : "Movie";
        }

        return {
            "name": title,
            "description": desc,
            "icon": "movie",
            "isTablerIcon": true,
            "isImage": false,
            "hideIcon": false,
            "singleLine": false,
            "provider": root,
            "onActivate": function() {
                root.activateEntry(item);
                if (launcher) launcher.close();
            }
        };
    }

    function getImageUrl(modelData) {
        return null;
    }

    function activateEntry(item) {
        let streamUrl = serverUrl + "/Items/" + item.Id + "/Download?api_key=" + apiKey;
        Logger.i("JellyfinProvider", "Playing item " + item.Id + " in mpv");
        Quickshell.execDetached(["mpv", streamUrl]);
    }
}
