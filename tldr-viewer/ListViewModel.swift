//
//  ListViewModel.swift
//  tldr-viewer
//
//  Created by Matthew Flint on 30/12/2015.
//  Copyright © 2015 Green Light. All rights reserved.
//

import Foundation
import UIKit

class ListViewModel: NSObject, UISplitViewControllerDelegate {
    // no-op closures until the ViewController provides its own
    var updateSignal: () -> Void = {}
    var showDetail: (detailViewModel: DetailViewModel) -> Void = {(vm) in}
    var cancelSearchSignal: () -> Void = {}
    
    internal var searchText: String = ""
    
    internal var itemSelected: Bool = false
    
    private let dataSource = DataSource()
    private var cellViewModels = [BaseCellViewModel]()
    
    internal var sectionViewModels = [SectionViewModel]()
    internal var sectionIndexes = [String]()
    
    override init() {
        super.init()
        self.dataSource.updateSignal = {
            self.updateCellViewModels()
        }
        
        self.updateCellViewModels()
    }
    
    private func updateCellViewModels() {
        var vms = [BaseCellViewModel]()
        
        let commands = dataSource.commands
        
        if dataSource.requesting {
            let cellViewModel = LoadingCellViewModel()
            vms.append(cellViewModel)
        }
        
        if let errorText = dataSource.requestError {
            let cellViewModel = ErrorCellViewModel(errorText: errorText, buttonAction: {
                self.dataSource.beginRequest()
            })
            vms.append(cellViewModel)
        }
        
        for command in commands {
            let cellViewModel = CommandCellViewModel(command: command, action: {
                let detailViewModel = DetailViewModel(command: command)
                self.showDetail(detailViewModel: detailViewModel)
            })
            vms.append(cellViewModel)
        }
        
        self.cellViewModels = vms
        self.makeFilteredSectionsAndCells()
        self.updateSignal()
    }
    
    private func makeFilteredSectionsAndCells() {
        let filteredCellViewModels = self.cellViewModels.filter{ cellViewModel in
            // if the search string is empty, return everything
            if self.searchText.characters.count == 0 {
                return true
            }
            
            // otherwise 
            if let commandCellViewModel = cellViewModel as? CommandCellViewModel {
                return commandCellViewModel.command.name.lowercaseString.containsString(self.searchText.lowercaseString)
            }
            
            return true
        }
        
        // all sections
        var sections = [SectionViewModel]()
        
        // current section
        var currentSection: SectionViewModel?
        
        for cellViewModel in filteredCellViewModels {
            if currentSection == nil || !currentSection!.accept(cellViewModel) {
                currentSection = SectionViewModel(firstCellViewModel: cellViewModel)
                sections.append(currentSection!)
            }
        }
        
        self.sectionViewModels = SectionViewModel.sort(sections)
        self.sectionIndexes = self.sectionViewModels.map({ section in section.title })
    }
    
    func didSelectRowAtIndexPath(indexPath: NSIndexPath) {
        self.itemSelected = true
        self.sectionViewModels[indexPath.section].cellViewModels[indexPath.row].performAction()
        self.cancelSearchSignal()
    }
    
    func filterTextDidChange(text: String) {
        self.searchText = text
        self.makeFilteredSectionsAndCells()
        self.updateSignal()
    }
    
    // MARK: - Split view
    
    // not called for iPhone 6+ or iPad
    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController, ontoPrimaryViewController primaryViewController: UIViewController) -> Bool {
        return !self.itemSelected
    }
    
    func splitViewController(svc: UISplitViewController, shouldHideViewController vc: UIViewController, inOrientation orientation: UIInterfaceOrientation) -> Bool {
        return self.itemSelected && UIInterfaceOrientationIsPortrait(orientation)
    }
}
