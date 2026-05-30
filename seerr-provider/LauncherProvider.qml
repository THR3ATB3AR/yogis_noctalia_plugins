import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null
    property string name: "Seerr"
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
    
    // Path state for drill-down: Array of {id, type, title}
    property var pathState: []
    
    // Server Details State
    property var currentServerProfiles: []
    property var currentServerTags: []
    property var selectedTags: []
    property bool isFetchingDetails: false

    property var radarrServers: []
    property var sonarrServers: []

    // Settings
    property string serverUrl: pluginApi?.pluginSettings?.serverUrl || ""
    property string apiKey: pluginApi?.pluginSettings?.apiKey || ""

    Timer {
        id: debounceTimer
        interval: 400
        repeat: false
        onTriggered: {
            root.performSearch(root.currentSearchText)
        }
    }

    function init() {
        Logger.i("SeerrProvider", "init called");
    }

    function onOpened() {
        supportedLayouts = "list";
        serverUrl = pluginApi?.pluginSettings?.serverUrl || "";
        apiKey = pluginApi?.pluginSettings?.apiKey || "";
        
        pathState = [];
        
        if (serverUrl && apiKey) {
            fetchServers("radarr");
            fetchServers("sonarr");
        }
    }

    function fetchServers(type) {
        let baseUrl = serverUrl.endsWith('/') ? serverUrl.slice(0, -1) : serverUrl;
        let url = baseUrl + "/api/v1/service/" + type;
        
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("X-Api-Key", apiKey);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    let servers = JSON.parse(xhr.responseText);
                    if (type === "radarr") {
                        radarrServers = servers;
                    } else {
                        sonarrServers = servers;
                    }
                } catch (e) {
                    Logger.e("SeerrProvider", "Failed to parse " + type + " servers");
                }
            }
        };
        xhr.send();
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">seerr ");
    }

    function commands() {
        return [{
            "name": ">seerr",
            "description": "Search and request media from Seerr",
            "icon": "movie",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function() {
                launcher.setSearchText(">seerr ");
            }
        }];
    }

    function getExpectedPrefix() {
        let prefix = ">seerr ";
        for (let i = 0; i < pathState.length; i++) {
            prefix += pathState[i].title + "/";
        }
        return prefix;
    }

    function getResults(searchText) {
        if (!searchText.startsWith(">seerr ")) return [];

        let prefix = getExpectedPrefix();
        
        // If user backspaced out of our path, pop pathState
        while (!searchText.startsWith(prefix) && pathState.length > 0) {
            let p = [];
            for (let i = 0; i < pathState.length - 1; i++) {
                p.push(pathState[i]);
            }
            pathState = p;
            prefix = getExpectedPrefix();
        }

        let query = searchText.slice(prefix.length).trim();

        if (query !== lastQuery || prefix !== lastPrefix) {
            lastQuery = query;
            lastPrefix = prefix;
            currentSearchText = query;
            
            // Show servers if we have drilled down
            if (pathState.length > 0) {
                showNextStep();
            } else {
                debounceTimer.restart();
            }
        }

        if (isSearching) {
            return [{
                "name": "Searching...",
                "description": "Querying Seerr server...",
                "icon": "refresh",
                "isTablerIcon": true,
                "isImage": false,
                "onActivate": function() {}
            }];
        }

        return searchResults;
    }

    function fetchServerDetails(mediaType, serverId) {
        isFetchingDetails = true;
        currentServerProfiles = [];
        currentServerTags = [];
        selectedTags = [];

        let baseUrl = serverUrl.endsWith('/') ? serverUrl.slice(0, -1) : serverUrl;
        let url = baseUrl + "/api/v1/service/" + (mediaType === "movie" ? "radarr" : "sonarr") + "/" + serverId;
        
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("X-Api-Key", apiKey);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isFetchingDetails = false;
                if (xhr.status === 200) {
                    try {
                        let data = JSON.parse(xhr.responseText);
                        currentServerProfiles = data.profiles || [];
                        currentServerTags = data.tags || (data.server && data.server.tags) || [];
                    } catch (e) {
                        Logger.e("SeerrProvider", "Failed to parse server details");
                    }
                }
                if (launcher && pathState.length === 2) showNextStep();
            }
        };
        xhr.send();
    }

    function showNextStep() {
        if (pathState.length === 0) return;
        
        if (pathState.length === 1) {
            let mediaItem = pathState[0];
            let servers = mediaItem.type === "movie" ? radarrServers : sonarrServers;
            
            if (servers.length === 0) {
                searchResults = [{
                    "name": "No Servers Found",
                    "description": "Could not find any configured " + (mediaItem.type === "movie" ? "Radarr" : "Sonarr") + " servers.",
                    "icon": "alert-circle",
                    "isTablerIcon": true,
                    "isImage": false,
                    "onActivate": function() {}
                }];
                if (launcher) launcher.updateResults();
                return;
            }

            searchResults = servers.map(server => {
                let desc = server.activeDirectory || "";
                if (server.is4k) {
                    desc += (desc ? " | " : "") + "4K";
                }
                
                return {
                    "name": "Request on " + server.name,
                    "description": desc,
                    "icon": "server",
                    "isTablerIcon": true,
                    "isImage": false,
                    "itemId": server.id,
                    "hideIcon": false,
                    "singleLine": false,
                    "provider": root,
                    "onActivate": function() {
                        let newPath = [];
                        for (let i = 0; i < pathState.length; i++) newPath.push(pathState[i]);
                        newPath.push({id: server.id, type: "server", title: server.name, rootFolder: server.activeDirectory});
                        pathState = newPath;
                        fetchServerDetails(mediaItem.type, server.id);
                        if (launcher) launcher.setSearchText(getExpectedPrefix());
                    }
                };
            });
            
            if (launcher) launcher.updateResults();
        } else if (pathState.length === 2) {
            if (isFetchingDetails) {
                searchResults = [{
                    "name": "Loading Profiles...",
                    "description": "Fetching server configuration from Seerr...",
                    "icon": "loader",
                    "isTablerIcon": true,
                    "isImage": false,
                    "onActivate": function() {}
                }];
                if (launcher) launcher.updateResults();
                return;
            }

            if (currentServerProfiles.length === 0) {
                searchResults = [{
                    "name": "No Profiles Found",
                    "description": "No quality profiles configured on this server.",
                    "icon": "alert-circle",
                    "isTablerIcon": true,
                    "isImage": false,
                    "onActivate": function() {}
                }];
                if (launcher) launcher.updateResults();
                return;
            }

            searchResults = currentServerProfiles.map(profile => {
                return {
                    "name": profile.name,
                    "description": "Quality Profile",
                    "icon": "list",
                    "isTablerIcon": true,
                    "isImage": false,
                    "itemId": profile.id,
                    "hideIcon": false,
                    "singleLine": false,
                    "provider": root,
                    "onActivate": function() {
                        let newPath = [];
                        for (let i = 0; i < pathState.length; i++) newPath.push(pathState[i]);
                        newPath.push({id: profile.id, type: "profile", title: profile.name});
                        pathState = newPath;
                        selectedTags = [];
                        if (launcher) launcher.setSearchText(getExpectedPrefix());
                    }
                };
            });
            
            if (launcher) launcher.updateResults();
        } else if (pathState.length === 3) {
            let results = [];

            results.push({
                "name": "🚀 Submit Request",
                "description": selectedTags.length > 0 ? "With " + selectedTags.length + " tag(s)" : "Submit immediately",
                "icon": "send",
                "isTablerIcon": true,
                "isImage": false,
                "hideIcon": false,
                "singleLine": false,
                "provider": root,
                "onActivate": function() {
                    let mediaItem = pathState[0];
                    let serverItem = pathState[1];
                    let profileItem = pathState[2];
                    requestMedia(mediaItem.id, mediaItem.type, serverItem.id, profileItem.id, serverItem.rootFolder, selectedTags);
                }
            });

            currentServerTags.forEach(tag => {
                let isSelected = false;
                for (let i = 0; i < selectedTags.length; i++) {
                    if (selectedTags[i] === tag.id) isSelected = true;
                }
                
                let tagName = tag.label || tag.name || "Tag " + tag.id;
                
                results.push({
                    "name": isSelected ? "✓ " + tagName : tagName,
                    "description": "Tag",
                    "icon": "tag",
                    "isTablerIcon": true,
                    "isImage": false,
                    "itemId": tag.id,
                    "hideIcon": false,
                    "singleLine": false,
                    "provider": root,
                    "onActivate": function() {
                        let newSelected = [];
                        let found = false;
                        for (let i = 0; i < selectedTags.length; i++) {
                            if (selectedTags[i] === tag.id) {
                                found = true;
                            } else {
                                newSelected.push(selectedTags[i]);
                            }
                        }
                        if (!found) newSelected.push(tag.id);
                        selectedTags = newSelected;
                        showNextStep(); // refresh list
                    }
                });
            });

            searchResults = results;
            if (launcher) launcher.updateResults();
        }
    }

    function performSearch(query) {
        if (pathState.length > 0) return; // Handled by showServerList

        let baseUrl = serverUrl.endsWith('/') ? serverUrl.slice(0, -1) : serverUrl;

        if (!baseUrl || !apiKey) {
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

        if (query === "") {
            searchResults = [{
                "name": "Search Seerr",
                "description": "Type to search for movies or TV shows...",
                "icon": "search",
                "isTablerIcon": true,
                "isImage": false,
                "onActivate": function() {}
            }];
            if (launcher) launcher.updateResults();
            return;
        }

        isSearching = true;
        if (launcher) launcher.updateResults();

        let url = baseUrl + "/api/v1/search?query=" + encodeURIComponent(query);

        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("X-Api-Key", apiKey);
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isSearching = false;
                if (xhr.status === 200) {
                    try {
                        let response = JSON.parse(xhr.responseText);
                        let items = response.results || [];
                        searchResults = items.filter(i => i.mediaType === "movie" || i.mediaType === "tv").map(item => formatEntry(item));
                        
                        if (searchResults.length === 0) {
                            searchResults = [{
                                "name": "No results",
                                "description": "No media found.",
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
                        "description": "Could not connect to Seerr. HTTP Status: " + xhr.status,
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
        let title = item.title || item.name;
        let desc = item.mediaType === "movie" ? "Movie" : "TV Show";
        
        if (item.releaseDate || item.firstAirDate) {
            let dateStr = item.releaseDate || item.firstAirDate;
            desc += " (" + dateStr.substring(0, 4) + ")";
        }

        let isImage = false;
        let iconStr = item.mediaType === "movie" ? "movie" : "device-tv";
        
        if (item.posterPath) {
            isImage = true;
        }

        return {
            "name": title,
            "description": isImage ? "\u200B • " + desc : desc,
            "icon": iconStr,
            "isTablerIcon": !isImage,
            "isImage": isImage,
            "itemId": item.id,
            "posterPath": item.posterPath,
            "hideIcon": false,
            "singleLine": false,
            "provider": root,
            "onActivate": function() {
                activateEntry(item, title);
            }
        };
    }

    function activateEntry(item, title) {
        let newPath = [];
        for (let i = 0; i < pathState.length; i++) {
            newPath.push(pathState[i]);
        }
        newPath.push({id: item.id, type: item.mediaType, title: title});
        pathState = newPath;
        
        let prefix = getExpectedPrefix();
        if (launcher) launcher.setSearchText(prefix);
    }

    function getImageUrl(modelData) {
        if (!modelData || !modelData.posterPath) return null;
        return "https://image.tmdb.org/t/p/w92" + modelData.posterPath;
    }
    
    function requestMedia(mediaId, mediaType, serverId, profileId, rootFolder, tags) {
        let baseUrl = serverUrl.endsWith('/') ? serverUrl.slice(0, -1) : serverUrl;
        let url = baseUrl + "/api/v1/request";
        
        let xhr = new XMLHttpRequest();
        xhr.open("POST", url);
        xhr.setRequestHeader("X-Api-Key", apiKey);
        xhr.setRequestHeader("Content-Type", "application/json");
        
        let body = {
            "mediaType": mediaType,
            "mediaId": mediaId,
            "serverId": serverId,
            "profileId": profileId,
            "rootFolder": rootFolder
        };
        
        if (tags && tags.length > 0) {
            body.tags = tags;
        }
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 201 || xhr.status === 200) {
                    Quickshell.execDetached(["notify-send", "-u", "normal", "Seerr", "Media requested successfully!"]);
                } else {
                    Quickshell.execDetached(["notify-send", "-u", "critical", "Seerr", "Failed to request media: " + xhr.status]);
                }
            }
        };
        xhr.send(JSON.stringify(body));
        
        if (launcher) launcher.close();
    }
}
