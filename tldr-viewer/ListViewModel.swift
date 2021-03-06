//
//  ListViewModel.swift
//  tldr-viewer
//
//  Created by Matthew Flint on 30/12/2015.
//  Copyright © 2015 Green Light. All rights reserved.
//

import Foundation
import UIKit

class ListViewModel: NSObject {
    // no-op closures until the ViewController provides its own
    var updateSignal: (_ indexPath: IndexPath?) -> Void = {(indexPath) in}
    var showDetail: (_ detailViewModel: DetailViewModel) -> Void = {(vm) in}
    var cancelSearchSignal: () -> Void = {}

    var canSearch: Bool = false
    var canRefresh: Bool = false
    
    var lastUpdatedString: String!
    var searchText: String = ""
    let searchPlaceholder = Localizations.CommandList.AllCommands.SearchPlaceholder
    var itemSelected: Bool = false
    var requesting: Bool = false
    var sectionViewModels = [SectionViewModel]()
    var sectionIndexes = [String]()
    
    var searchableDataSource: SearchableDataSourceType!
    var dataSources: [DataSourceType]!
    var dataSourceNames: [String]!
    
    var detailVisible: Bool = false
    
    private let dateFormatter = DateFormatter()
    private var selectedDataSource: DataSourceType!
    var selectedDataSourceIndex: Int! {
        didSet {
            selectedDataSource = dataSources[selectedDataSourceIndex]
            selectedDataSource.updateSignal = {
                self.update()
            }
            
            if let _ = selectedDataSource as? SearchableDataSourceType {
                canSearch = true
                canRefresh = true
            } else {
                canSearch = false
                canRefresh = false
            }
            
            refreshableDataSource = selectedDataSource as? RefreshableDataSourceType

            Preferences.sharedInstance.setCurrentDataSource(selectedDataSource.type)
            
            update()
        }
    }
    
    private var refreshableDataSource: RefreshableDataSourceType?
    private var cellViewModels = [BaseCellViewModel]()
    
    override init() {
        super.init()
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        dataSources = [DataSource.sharedInstance, FavouriteDataSource.sharedInstance]
        dataSourceNames = []
        for dataSource in dataSources {
            dataSourceNames.append(dataSource.name)
            if let searchable = dataSource as? SearchableDataSourceType {
                searchableDataSource = searchable
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(ListViewModel.externalCommandChange(notification:)), name: Constant.ExternalCommandChangeNotification.name, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ListViewModel.detailShown(notification:)), name: Constant.DetailViewPresence.shownNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ListViewModel.detailHidden(notification:)), name: Constant.DetailViewPresence.hiddenNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewModel.favouriteChange(notification:)), name: Constant.FavouriteChangeNotification.name, object: nil)
        
        defer {
            let currentDataSourceType = Preferences.sharedInstance.currentDataSource()
            for (index, dataSource) in dataSources.enumerated() {
                if currentDataSourceType == dataSource.type {
                    selectedDataSourceIndex = index
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func externalCommandChange(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let commandName = userInfo[Constant.ExternalCommandChangeNotification.commandNameKey] as? String else { return }
        
        selectedDataSourceIndex = 0
        
        if let searchableDataSource = selectedDataSource as? SearchableDataSourceType {
            if let command = searchableDataSource.commandWith(name: commandName) {
                showCommand(commandName: command.name)
            }
        }
    }
    
    @objc func detailShown(notification: Notification) {
        detailVisible = true
    }
    
    @objc func detailHidden(notification: Notification) {
        detailVisible = false
    }
    
    @objc func favouriteChange(notification: Notification) {
        update()
    }
    
    func refreshData() {
        refreshableDataSource?.beginRequest()
    }
    
    private func update() {
        var vms = [BaseCellViewModel]()
        var commands: [Command]
        if let searchableDataSource = selectedDataSource as? SearchableDataSourceType {
            commands = searchableDataSource.commandsWith(filter: searchText)
        } else {
            commands = selectedDataSource.allCommands()
        }
        
        if let refreshableDataSource = self.refreshableDataSource {
            requesting = refreshableDataSource.requesting
            if let lastUpdateTime = refreshableDataSource.lastUpdateTime() {
                let lastUpdatedDateTime = dateFormatter.string(from: lastUpdateTime)
                lastUpdatedString = Localizations.CommandList.AllCommands.UpdatedDateTime(value1: lastUpdatedDateTime)
            } else {
                lastUpdatedString = ""
            }
            
            if commands.count == 0 {
                if refreshableDataSource.requesting {
                    let cellViewModel = LoadingCellViewModel()
                    vms.append(cellViewModel)
                } else if searchText.characters.count > 0 {
                    // search had no results
                    let cellViewModel = NoResultsCellViewModel(searchTerm: searchText, buttonAction: {
                        let url = URL(string: "https://github.com/tldr-pages/tldr/blob/master/CONTRIBUTING.md")!
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    })
                    vms.append(cellViewModel)
                }
            }
            
            if let errorText = refreshableDataSource.requestError {
                let cellViewModel = ErrorCellViewModel(errorText: errorText, buttonAction: {
                    refreshableDataSource.beginRequest()
                })
                vms.append(cellViewModel)
            } else if let oldIndexCell = OldIndexCellViewModel.create(dataSource: refreshableDataSource) {
                vms.append(oldIndexCell)
            }
        }
        
        if selectedDataSource.type == .favourites && commands.count == 0 {
            vms.append(NoFavouritesCellViewModel())
        }
        
        for command in commands {
            let cellViewModel = CommandCellViewModel(command: command, action: {
                let detailViewModel = DetailViewModel(dataSource: self.searchableDataSource, command: command)
                self.showDetail(detailViewModel)
            })
            vms.append(cellViewModel)
        }
        
        cellViewModels = vms
        makeSectionsAndCells()
        updateSignal(nil)
    }
    
    private func makeSectionsAndCells() {
        // all sections
        var sections = [SectionViewModel]()
        
        // current section
        var currentSection: SectionViewModel?
        
        for cellViewModel in cellViewModels {
            if currentSection == nil || !currentSection!.accept(cellViewModel: cellViewModel) {
                currentSection = SectionViewModel(firstCellViewModel: cellViewModel)
                sections.append(currentSection!)
            }
        }
        
        sectionViewModels = SectionViewModel.sort(sections: sections)
        sectionIndexes = sectionViewModels.map({ section in section.title })
    }
    
    func didSelectRow(at indexPath: IndexPath) {
        selectRow(indexPath: indexPath)
        cancelSearchSignal()
    }
    
    private func selectRow(indexPath: IndexPath) {
        itemSelected = true
        sectionViewModels[indexPath.section].cellViewModels[indexPath.row].performAction()
    }
    
    func filterTextDidChange(text: String) {
        searchText = text
        update()
    }
    
    func showCommand(commandName: String) {
        // kill any search
        searchText = ""
        cancelSearchSignal()
        
        // update the results (to show all cells)
        update()
        
        // now find the NSIndexPath for the CommandCellViewModel for this command name
        var indexPath: IndexPath?
        for (sectionIndex, sectionViewModel) in sectionViewModels.enumerated() {
            for (cellIndex, cellViewModel) in sectionViewModel.cellViewModels.enumerated() {
                if let commandCellViewModel = cellViewModel as? CommandCellViewModel {
                    if commandCellViewModel.command.name == commandName {
                        indexPath = IndexPath(row: cellIndex, section: sectionIndex)
                    }
                }
            }
        }
        
        if let indexPath = indexPath {
            if (!detailVisible) {
                // this will trigger the segue. If detail already visible, the detail viewmodel will handle it
                selectRow(indexPath: indexPath)
            }
            updateSignal(indexPath)
        }
    }
    
    func showDetailWhenHorizontallyCompact() -> Bool {
        return itemSelected
    }
}
