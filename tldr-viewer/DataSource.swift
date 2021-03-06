//
//  DataSource.swift
//  tldr-viewer
//
//  Created by Matthew Flint on 23/01/2016.
//  Copyright © 2016 Green Light. All rights reserved.
//

import Foundation
import Zip

public class DataSource: DataSourceType, RefreshableDataSourceType, SearchableDataSourceType {
    private let commandNameBlackList = ["fuck"] // this is a family show
    
    private let documentsDirectory : URL!
    private let zipFileURL : URL!
    private let indexFileURL : URL!
    
    static let sharedInstance = DataSource()
    let name = Localizations.CommandList.DataSources.All
    let type = Preferences.DataSourceEnumType.all
    
    // no-op closures until the ViewModel provides its own
    var updateSignal: () -> Void = {}
    var requesting = false
    var requestError: String?
    private var commands = [Command]()
    private var commandsByName = [String:Command]()
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        zipFileURL = documentsDirectory.appendingPathComponent("tldr.zip")
        indexFileURL = documentsDirectory.appendingPathComponent("pages").appendingPathComponent("index.json")
        
        if !loadCommandsFromIndexFile() {
            beginRequest()
        }
    }
    
    func beginRequest() {
        if requesting {
            return
        }
        
        requesting = true
        requestError = nil
        
        TLDRRequest.requestWithURL(urlString: "https://tldr.sh/assets/tldr.zip") { response in
            self.processResponse(response: response)
        }
        
        updateSignal()
    }
    
    func lastUpdateTime() -> Date? {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: indexFileURL.path)
            return fileAttributes[FileAttributeKey.modificationDate] as? Date
        } catch {
            return nil
        }
    }
    
    func allCommands() -> [Command] {
        return commands
    }
    
    func commandsWith(filter: String) -> [Command] {
        // if the search string is empty, return everything
        if filter.characters.count == 0 {
            return commands
        }
        
        let lowercasedFilter = filter.lowercased()
        return commandsWith(filter: { (command) -> Bool in
            return command.name.lowercased().contains(lowercasedFilter)
        })
    }
    
    func commandsWith(filter: (Command) -> Bool) -> [Command] {
        return commands.filter(filter)
    }
    
    func commandWith(name: String) -> Command? {
        return commandsByName[name]
    }
    
    private func processResponse(response: TLDRResponse) {
        if let error = response.error {
            handle(error: error)
        } else {
            handleSuccess(data: response.data)
        }
        
        requesting = false
        updateSignal()
    }
    
    private func handle(error: Error) {
        requestError = Localizations.CommandList.Error.CouldNotDownload
    }
    
    private func handleSuccess(data: Data) {
        if !save(zipData:data) {
            return
        }
        
        if !unzipSavedFile() {
            return
        }
        
        if loadCommandsFromIndexFile() {
            DispatchQueue.global(qos: .background).async {
                self.addToSpotlightIndex()
            }
        }
    }
    
    private func addToSpotlightIndex() {
        let spotlightSearch = SpotlightSearch()
        
        for command in self.commands {
            spotlightSearch.addToIndex(command: command)
        }
    }
    
    private func loadCommandsFromIndexFile() -> Bool {
        guard let indexFileContents = indexFileContents() else {
            return false
        }
        
        if indexFileContents.count == 0 {
            return false
        }
        
        (self.commands, self.commandsByName) = commandsFrom(indexFile: indexFileContents)
        
        return true
    }
    
    private func save(zipData: Data) -> Bool {
        do {
            try zipData.write(to: zipFileURL, options: (.atomic))
        } catch {
            requestError = Localizations.CommandList.Error.CouldNotSaveDownload
            return false
        }
        
        return true
    }
    
    private func unzipSavedFile() -> Bool {
        do {
            try Zip.unzipFile(zipFileURL, destination: documentsDirectory, overwrite: true, password: nil, progress: nil)
            return true
        }
        catch {
            requestError = Localizations.CommandList.Error.CouldNotUnzipDownload
            return false
        }
    }
    
    private func indexFileContents() -> Array<Dictionary<String, AnyObject>>? {
        
        do {
            let indexData = try Data(contentsOf: indexFileURL)
            let jsonResult = try JSONSerialization.jsonObject(with: indexData, options: [])
            
            // sometimes we get an array as the top level object...
            if let jsonResult = jsonResult as? Array<Dictionary<String, AnyObject>> {
                return jsonResult
            }
            
            // ... sometimes that array is inside a map ¯\_(ツ)_/¯
            if let jsonResult = jsonResult as? Dictionary<String, Array<Dictionary<String, AnyObject>>> {
                return jsonResult["commands"]
            }
        }  catch let error as NSError {
            requestError = Localizations.CommandList.Error.CouldNotReadIndexFile
            print (error)
        }
        
        return nil
    }
    
    private func commandsFrom(indexFile: Array<Dictionary<String, AnyObject>>) -> ([Command],[String:Command]) {
        var commands = [Command]()
        var commandsByName = [String:Command]()
        
        for commandJSON in indexFile {
            let name = commandJSON["name"] as! String
            
            guard !commandNameBlackList.contains(name) else { continue }
            
            var platforms = [Platform]()
            for platformName in commandJSON["platform"] as! Array<String> {
                let platform = Platform.get(name: platformName)
                platforms.append(platform)
            }
            let command = Command(name: name , platforms: Platform.sort(platforms: platforms))
            
            commands.append(command)
            commandsByName[name] = command
        }
        
        return (commands, commandsByName)
    }
}
