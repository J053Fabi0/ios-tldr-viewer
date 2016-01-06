//
//  ListViewController.swift
//  tldr-viewer
//
//  Created by Matthew Flint on 30/12/2015.
//  Copyright © 2015 Green Light. All rights reserved.
//

import UIKit

class ListViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            self.tableView.sectionIndexColor = UIColor.tldrTeal()
        }
    }
    @IBOutlet weak var searchBar: UISearchBar! {
        didSet {
            self.searchBar.autocapitalizationType = UITextAutocapitalizationType.None
        }
    }
    
    private var viewModel: ListViewModel! {
        didSet {
            self.viewModel.updateSignal = {
                dispatch_async(dispatch_get_main_queue(), {
                    self.tableView.reloadData()
                })
            }
            
            self.viewModel.showDetail = {(detailViewModel) -> Void in
                // show the detail
                self.performSegueWithIdentifier("showDetail", sender: detailViewModel)
                
                // and dismiss the primary overlay VC if necessary (iPad only)
                if (self.splitViewController?.displayMode == .PrimaryOverlay){
                    self.splitViewController?.preferredDisplayMode = .PrimaryHidden
                    self.splitViewController?.preferredDisplayMode = .Automatic
                }         }
            
            self.splitViewController?.delegate = self.viewModel
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.viewModel = ListViewModel()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // iPhone 6 or smaller: deselect the selected row when this ViewController reappears
        if self.splitViewController!.collapsed {
            if let selectedRow = self.tableView.indexPathForSelectedRow {
                self.tableView.deselectRowAtIndexPath(selectedRow, animated: true)
            }
        }
    }

    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            let detailVC = (segue.destinationViewController as! UINavigationController).topViewController as! DetailViewController
            
            if let detailViewModel = sender as? DetailViewModel {
                detailVC.viewModel = detailViewModel
            }
            
            detailVC.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
            detailVC.navigationItem.leftItemsSupplementBackButton = true
        } else if segue.identifier == "showInfoPopover" {
            // this sets the color of the popover arrow on iPad, to match the UINavigationBar color of the destination VC
            segue.destinationViewController.popoverPresentationController?.backgroundColor = UIColor.tldrTeal()
        }
    }
}

// MARK: - UITableViewDataSource

extension ListViewController: UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if let viewModel = self.viewModel {
            return viewModel.sectionViewModels.count
        }
        
        return 0
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let viewModel = self.viewModel {
            return viewModel.sectionViewModels[section].cellViewModels.count
        }
        
        return 0
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.viewModel.sectionViewModels[section].title
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellViewModel = self.viewModel.sectionViewModels[indexPath.section].cellViewModels[indexPath.row]
        let cell = tableView.dequeueReusableCellWithIdentifier(cellViewModel.cellIdentifier, forIndexPath: indexPath)
        if let baseCell = cell as? BaseCell {
            baseCell.configure(cellViewModel)
        }
        return cell
    }
    
    func sectionIndexTitlesForTableView(tableView: UITableView) -> [String]? {
        return self.viewModel.sectionIndexes
    }
}

// MARK: - UITableViewDelegate

extension ListViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.viewModel.didSelectRowAtIndexPath(indexPath)
        self.searchBar.resignFirstResponder()
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // don't show sections
        return 0
    }
}

// MARK: - UISearchBarDelegate

extension ListViewController: UISearchBarDelegate {
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        self.viewModel.filterTextDidChange(searchText)
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
