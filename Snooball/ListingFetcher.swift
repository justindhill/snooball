//
//  ListingFetcher.swift
//  Snooball
//
//  Created by Justin Hill on 3/12/17.
//  Copyright © 2017 Justin Hill. All rights reserved.
//

import Foundation
import reddift

fileprivate let SERIAL_QUEUE_LABEL = "com.justinhill.snooball.listing_fetcher"


class ListingFetcher<T: Thing>: NSObject {
    var paginator: Paginator? = Paginator()
    let subreddit: Subreddit
    let sortOrder: LinkSortType
    private(set) var things = [T]()
    
    private var _fetching = false
    var fetching: Bool {
        get {
            return self.serialQueue.sync {
                return _fetching
            }
        }
    }
    
    private var _moreAvailable = true
    var moreAvailable: Bool {
        get {
            return self.serialQueue.sync {
                return _moreAvailable
            }
        }
    }
    
    let serialQueue = DispatchQueue(label: SERIAL_QUEUE_LABEL)
    
    init(subreddit: Subreddit, sortOrder: LinkSortType) {
        self.subreddit = subreddit
        self.sortOrder = sortOrder
        super.init()
    }
    
    func fetchMore(completion outerCompletion: @escaping (_ error: Error?, _ newThings: Int) -> Void) {
        do {
            guard let paginator = self.paginator else {
                outerCompletion(NSError(domain: "ListingFetcher", code: 0, userInfo: [NSLocalizedDescriptionKey: "Some unknown error happened"]), 0)
                return
            }
            
            self.serialQueue.sync {
                self._fetching = true
            }
            
            try AppDelegate.shared.session?.getList(paginator, subreddit: subreddit, sort: self.sortOrder, timeFilterWithin: .all, completion: { (result) in
                guard let things = result.value?.children as? [T] else {
                    DispatchQueue.main.async {
                        outerCompletion(NSError(domain: "ListingFetcher", code: 0, userInfo: [NSLocalizedDescriptionKey: "Some unknown error happened"]), 0)
                    }
                    
                    return
                }
            
                self.serialQueue.sync {
                    self.things = (self.things + things)
                    self._fetching = false
                    self._moreAvailable = result.value?.paginator.isVacant == false
                    self.paginator = result.value?.paginator
                }
                
                DispatchQueue.main.async {
                    outerCompletion(nil, things.count)
                }
            })
        } catch {
            DispatchQueue.main.async {
                outerCompletion(error, 0)
            }
        }
    }
}
