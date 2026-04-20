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
    property string lastPrefix: ""
    
    // Path state for drill-down: Array of {name, id, type}
    property var pathState: []

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
        serverUrl = pluginApi?.pluginSettings?.serverUrl || "";
        apiKey = pluginApi?.pluginSettings?.apiKey || "";
        userId = pluginApi?.pluginSettings?.userId || "";
        
        // Reset navigation path when opened
        let empty = [];
        pathState = empty;
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

    function getExpectedPrefix() {
        let prefix = ">jf ";
        for (let i = 0; i < pathState.length; i++) {
            prefix += pathState[i].name + "/";
        }
        return prefix;
    }

    function getResults(searchText) {
        if (!searchText.startsWith(">jf ")) return [];

        let prefix = getExpectedPrefix();
        
        // If user backspaced out of our path, pop pathState
        while (!searchText.startsWith(prefix) && pathState.length > 0) {
            let p = [];
            for (let i = 0; i < pathState.length - 1; i++) {
                p.push(pathState[i]);
            }
            pathState = p; // Reassign to trigger any bindings
            prefix = getExpectedPrefix();
        }

        let query = searchText.slice(prefix.length).trim();

        if (query !== lastQuery || prefix !== lastPrefix) {
            lastQuery = query;
            lastPrefix = prefix;
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

        let parentId = null;
        let parentType = null;
        if (pathState.length > 0) {
            let lastNode = pathState[pathState.length - 1];
            parentId = lastNode.id;
            parentType = lastNode.type;
        }

        let url = "";

        if (!parentId) {
            if (query === "") {
                // Show Libraries
                url = serverUrl + "/Users/" + userId + "/Views";
            } else {
                // Global search (no episodes!)
                url = serverUrl + "/Users/" + userId + "/Items?SearchTerm=" + encodeURIComponent(query) + "&Recursive=true&IncludeItemTypes=Movie,Series,CollectionFolder&Limit=20";
            }
        } else if (parentType === "CollectionFolder" || parentType === "UserView") {
            if (query === "") {
                // List Movies/Series in Library
                url = serverUrl + "/Users/" + userId + "/Items?ParentId=" + parentId + "&IncludeItemTypes=Movie,Series,Folder&SortBy=SortName";
            } else {
                // Search in Library (no episodes)
                url = serverUrl + "/Users/" + userId + "/Items?ParentId=" + parentId + "&SearchTerm=" + encodeURIComponent(query) + "&Recursive=true&IncludeItemTypes=Movie,Series,Folder&Limit=20";
            }
        } else if (parentType === "Series" || parentType === "Folder") {
            if (query === "") {
                // List Seasons
                url = serverUrl + "/Users/" + userId + "/Items?ParentId=" + parentId + "&IncludeItemTypes=Season,Folder&SortBy=SortName";
            } else {
                // Search Seasons
                url = serverUrl + "/Users/" + userId + "/Items?ParentId=" + parentId + "&SearchTerm=" + encodeURIComponent(query) + "&IncludeItemTypes=Season,Folder";
            }
        } else if (parentType === "Season") {
            if (query === "") {
                // List Episodes
                url = serverUrl + "/Users/" + userId + "/Items?ParentId=" + parentId + "&IncludeItemTypes=Episode&SortBy=SortName";
            } else {
                // Search Episodes in this season
                url = serverUrl + "/Users/" + userId + "/Items?ParentId=" + parentId + "&SearchTerm=" + encodeURIComponent(query) + "&IncludeItemTypes=Episode";
            }
        }

        if (url.indexOf("?") !== -1) {
            url += "&Fields=UserData";
        } else {
            url += "?Fields=UserData";
        }

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
                                "description": "No media found here.",
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
        let isPlayed = item.UserData && item.UserData.Played;
        let unplayedCount = item.UserData && item.UserData.UnplayedItemCount !== undefined ? item.UserData.UnplayedItemCount : 0;
        let isFolder = item.IsFolder || item.Type === "CollectionFolder" || item.Type === "UserView" || item.Type === "Series" || item.Type === "Season" || item.Type === "Folder";

        if (item.Type === "Episode") {
            desc = "Episode";
            if (item.IndexNumber !== undefined) {
                title = item.IndexNumber + ". " + title;
            }
            if (isPlayed) title = "✓ " + title;
        } else if (item.Type === "Movie") {
            desc = item.ProductionYear ? item.ProductionYear.toString() : "Movie";
            if (isPlayed) title = "✓ " + title;
        } else if (item.Type === "Series") {
            desc = "Series";
            if (unplayedCount > 0) desc += " (" + unplayedCount + " unplayed)";
            else if (isPlayed || (item.UserData && item.UserData.PlayedPercentage === 100)) title = "✓ " + title;
        } else if (item.Type === "Season") {
            desc = "Season";
            if (unplayedCount > 0) desc += " (" + unplayedCount + " unplayed)";
            else if (isPlayed || (item.UserData && item.UserData.PlayedPercentage === 100)) title = "✓ " + title;
        } else if (item.Type === "CollectionFolder" || item.Type === "UserView") {
            desc = "Library";
        }

        return {
            "name": title,
            "description": desc,
            "icon": isFolder ? "folder" : "movie",
            "isTablerIcon": true,
            "isImage": false,
            "hideIcon": false,
            "singleLine": false,
            "provider": root,
            "onActivate": function() {
                root.activateEntry(item);
            }
        };
    }

    function getImageUrl(modelData) {
        return null;
    }

    function activateEntry(item) {
        let isFolder = item.IsFolder || item.Type === "CollectionFolder" || item.Type === "UserView" || item.Type === "Series" || item.Type === "Season" || item.Type === "Folder";

        if (isFolder) {
            let newPath = [];
            for (let i = 0; i < pathState.length; i++) {
                newPath.push(pathState[i]);
            }
            newPath.push({name: item.Name, id: item.Id, type: item.Type});
            pathState = newPath;
            
            let prefix = getExpectedPrefix();
            if (launcher) launcher.setSearchText(prefix);
            // We intentionally do not call launcher.close() here!
        } else {
            let streamUrl = serverUrl + "/Items/" + item.Id + "/Download?api_key=" + apiKey;
            Logger.i("JellyfinProvider", "Playing item " + item.Id + " in mpv");
            Quickshell.execDetached(["mpv", streamUrl]);
            if (launcher) launcher.close();
        }
    }
}
