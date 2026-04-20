import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    // Plugin API provided by PluginService
    property var pluginApi: null

    // Provider metadata
    property string name: "Calculator"
    property var launcher: null
    property bool handleSearch: true
    property bool supportsAutoPaste: false

    property string supportedLayouts: "both"
    property real preferredGridColumns: 4
    property real preferredGridCellRatio: 1.0 
    property bool ignoreDensity: false

    function init() {
        Logger.i("CalculatorProvider", "init called");
    }

    function onOpened() {
        supportedLayouts = "list";
    }

    function handleCommand(searchText) {
        return searchText.startsWith("=");
    }

    // Return available commands when user types ">"
    function commands() {
        return [{
            "name": "= (Math)",
            "description": "Evaluate mathematical expression",
            "icon": "calculator",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function() {
                launcher.setSearchText("=");
            }
        }];
    }

    // Get search results
    function getResults(searchText) {
        if (!searchText) return [];

        let query = searchText.trim();
        let isForced = false;

        if (query.startsWith("=")) {
            query = query.slice(1).trim();
            isForced = true;
        }

        if (query.length === 0) return [];

        // Check if query looks like math (numbers, basic operators, parens)
        const looksLikeMath = /^[0-9\.\+\-\*\/\%\(\)\s\^]+$/.test(query);

        // If it doesn't look like basic math and it wasn't forced with '=', ignore it
        if (!isForced && !looksLikeMath) {
            return []; 
        }

        // Replace ^ with ** for Javascript power
        let evalQuery = query;
        if (looksLikeMath) {
            evalQuery = query.replace(/\^/g, '**');
        }

        try {
            // Using Function constructor to evaluate safely
            // Note: If users type `= Math.sqrt(16)`, it won't be caught by looksLikeMath, 
            // but isForced will be true, and it will be evaluated here.
            let result = Function('"use strict";return (' + evalQuery + ')')();
            
            // Only return result if it's a valid number
            if (result !== undefined && result !== null && !isNaN(result)) {
                return [formatEntry(query, result.toString())];
            }
        } catch (e) {
            // If it fails to parse/evaluate and the user forced it, show the error
            if (isForced) {
                 return [{
                    "name": "Error",
                    "description": e.toString(),
                    "icon": "alert-circle",
                    "isTablerIcon": true,
                    "isImage": false,
                    "onActivate": function() {}
                }];
            }
        }
        
        return [];
    }

    function formatEntry(query, result) {
        return {
          "name": result,           
          "description": query + " = " + result,   
          "icon": "calculator",                   
          "isTablerIcon": true,             
          "isImage": false,                 
          "hideIcon": false,                
          "singleLine": false,              
          "provider": root,                 
          "onActivate": function() {        
              root.activateEntry(result);
              if (launcher) launcher.close();
          },
        }
    }

    function getImageUrl(modelData) {
        return null;
    }

    function activateEntry(resultText) {
        Logger.i("CalculatorProvider", "Copying to clipboard: " + resultText);
        Quickshell.execDetached(["wl-copy", resultText]);
    }
}
