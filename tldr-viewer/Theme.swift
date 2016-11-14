//
//  Theme.swift
//  tldr-viewer
//
//  Created by Matthew Flint on 31/12/2015.
//  Copyright © 2015 Green Light. All rights reserved.
//

import Foundation
import UIKit

class Theme {
    static func setup() {
        // navigation bar and item
        UINavigationBar.appearance().titleTextAttributes = [NSForegroundColorAttributeName: UIColor.tldrLightBody(), NSFontAttributeName: UIFont.tldrBody()]
        UINavigationBar.appearance().barTintColor = UIColor.tldrTeal()
        UINavigationBar.appearance().tintColor = UIColor.tldrLightBody()
        UIBarButtonItem.appearance().setTitleTextAttributes([NSFontAttributeName: UIFont.tldrBody()], for: .normal)
        
        // segmented control
        UISegmentedControl.appearance().tintColor = UIColor.tldrTeal()
        
        // UISearchBar text field
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).font = UIFont.tldrBody()
    }
    
    static func css() -> String {
        let filePath = Bundle.main.url(forResource: "style", withExtension: "css")
        do {
            let data = try Data(contentsOf: filePath!)
            let cssString = String(data: data, encoding: String.Encoding.utf8)
            return cssString!
        } catch {
            return ""
        }
    }

    static func pageFrom(htmlSnippet: String) -> String {
        let result = "<html><head><meta name=\"viewport\" content=\"initial-scale=1.0\" /><style>" + css() + "</style></head><body>" + htmlSnippet + "</body></html>"
        return result
    }
    
    static func bodyAttributed(string: String?) -> NSAttributedString? {
        guard let string = string else {
            return nil
        }
        
        return NSAttributedString(string: string, attributes: [NSFontAttributeName:UIFont.tldrBody(), NSForegroundColorAttributeName:UIColor.tldrBody()])
    }
    
    static func detailAttributed(string: String?) -> NSAttributedString? {
        guard let string = string else {
            return nil
        }
        
        return NSAttributedString(string: string, attributes: [NSFontAttributeName:UIFont.tldrBody(), NSForegroundColorAttributeName:UIColor.tldrDetail()])
    }
}

extension UIFont {
    class func tldrBody() -> UIFont {
        return UIFont(name: "Avenir-Book", size: 16)!
    }
}

extension UIColor {
    class func tldrBody() -> UIColor {
        return UIColor(red: 33.0/255.0, green: 33.0/255.0, blue: 33.0/255.0, alpha: 1)
    }
    
    class func tldrDetail() -> UIColor {
        return UIColor.darkGray
    }
    
    class func tldrTeal() -> UIColor {
        return UIColor(red: 0, green: 0.5, blue: 0.5, alpha: 1)
    }
    
    class func tldrActionBackground() -> UIColor {
        return UIColor(red: 219.0/255.0, green: 243.0/255.0, blue: 242.0/255.0, alpha: 1)
    }
    
    class func tldrActionForeground() -> UIColor {
        return UIColor.darkGray
    }
    
    class func tldrLightBody() -> UIColor {
        return UIColor.white
    }
}
