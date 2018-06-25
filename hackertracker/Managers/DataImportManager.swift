//
//  DataImportManager.swift
//  hackertracker
//
//  Created by Christopher Mays on 7/11/17.
//  Copyright © 2017 Beezle Labs. All rights reserved.
//

import UIKit
import CoreData
class DataImportManager: NSObject {

    enum ImportError : Error {
        case idDoesntExist
    }
    let managedContext : NSManagedObjectContext
    
    public init(managedContext : NSManagedObjectContext) {
        self.managedContext = managedContext
        
        super.init()
    }
    
    public func importSpeakers(speakerData : Data) throws {
        //print("IMPORT SPEAKERS")
        let _speakers = try JSONSerialization.jsonObject(with: speakerData, options: .allowFragments) as? [String : Any]
        
        guard let speakers = _speakers, let updateDateString = speakers["update_date"] as? String, let _ = DateFormatterUtility.iso8601Formatter.date(from:updateDateString), let speakerItems = speakers["speakers"] as? [[String : Any]] else
        {
            print("Something is wrong with speaker import")
            return ;
        }
        
        for speaker in speakerItems
        {
            //print("SPEAKER: \(speaker)\n")
            if let _ = speaker["last_update"] as? String, let _ = speaker["indexsp"] as? Int32 {
                do {
                    _ = try importSpeaker(speaker: speaker)
                } catch {
                    assert(false, "Failed to import speaker \(speaker)")
                    print("Failed to import speaker \(speaker)")
                }
            }
        }
    }
    
    public func importSpeaker(speaker : [String : Any]) throws -> Speaker {
        guard let index = speaker["indexsp"] as? Int32 else {
            throw ImportError.idDoesntExist
        }
        
        let fre:NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Speaker")
        fre.predicate = NSPredicate(format: "indexsp = %@", argumentArray: [index])
        
        let ret = try managedContext.fetch(fre)
        
        let managedSpeaker : Speaker
        
        if let existingSpeaker = ret.first as? Speaker {
            //print("Existing Speaker \(index)")
            managedSpeaker = existingSpeaker
        } else {
            managedSpeaker = NSEntityDescription.insertNewObject(forEntityName: "Speaker", into: managedContext) as! Speaker
        }
        
        if let title = speaker["sptitle"] as? String {
            managedSpeaker.sptitle = title
        } else {
            managedSpeaker.sptitle = ""
        }
        
        if let who = speaker["who"] as? String {
            managedSpeaker.who = who
        } else {
            managedSpeaker.who = "Mystery Speaker"
        }
        
        managedSpeaker.indexsp = index
        
        if let lastUpdateString = speaker["last_update"] as? String, let lastUpdateDate =  DateFormatterUtility.iso8601Formatter.date(from: lastUpdateString) {
            managedSpeaker.last_update = lastUpdateDate
        } else {
            managedSpeaker.last_update = Date()
        }
        
        if let media = speaker["media"] as? String {
            managedSpeaker.media = media
        } else {
            managedSpeaker.media = ""
        }
        
        if let bio = speaker["bio"] as? String {
            managedSpeaker.bio = bio
        } else {
            managedSpeaker.bio = ""
        }
        
        try managedContext.save()
        
        return managedSpeaker
        
    }

    public func importEvents(eventData : Data) throws {
        let _events = try JSONSerialization.jsonObject(with: eventData, options: .allowFragments) as? [String : Any]
        
        guard let events = _events, let updateDateString = events["update_date"] as? String, let lastUpdateDate = DateFormatterUtility.iso8601Formatter.date(from:updateDateString), let eventItems = events["schedule"] as? [[String : Any]] else
        {
            return ;
        }
        
        for event in eventItems
        {
            if let _ = event["updated_at"] as? String, let _ = event["index"] {
                do {
                    _ = try importEvent(event: event)
                } catch let error {
                    print("Failed to import event \(event) error \(error)")
                }
            }
        }
        
        do {
            try setSyncDate(lastUpdateDate)
        } catch {
            assert(false, "Failed to save last update date")
            print("Failed to save last update date")
        }
    }
    
    public func importEvent(event : [String : Any]) throws -> Event {
        guard let id = event["id"] as? String else {
            throw ImportError.idDoesntExist
        }
        
        let fre:NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Event")
        fre.predicate = NSPredicate(format: "id = %@", argumentArray: [id])
        
        let ret = try managedContext.fetch(fre)
        
        let managedEvent : Event
        
        if let existingEvent = ret.first as? Event {
            managedEvent = existingEvent
            
        } else {
            managedEvent = NSEntityDescription.insertNewObject(forEntityName: "Event", into: managedContext) as! Event
            managedEvent.id = id
        }
        
        if let index = event["index"] as? Int32 {
            managedEvent.index = index
        } else {
            managedEvent.index = 0
            //throw ImportError.idDoesntExist
        }
        
        
        if let who = event["who"] as? [[String : Any]] {
            
            

            
            for eventData in who {
                
                if let speakerString = eventData["indexsp"] as? String, let speakerID = Int32(speakerString)
                {
                    
                    do {
                        try setSpeakerEventPair(eventID: managedEvent.index, speakerID: speakerID)
                    } catch {
                        assert(false, "Failed to import Speaker")
                        print("Failed to import Speaker \(event)")
                    }
                } else {
                    print("could not find indexsp, something is up")
                }
            }
        }
        
       
        
        if let includes = event["includes"] as? String {
            managedEvent.includes = includes
        } else {
            managedEvent.includes = ""
        }
        
        if var title = event["title"] as? String {
            
            if title.localizedCaseInsensitiveContains("Apple") {
                title = title.replacingOccurrences(of: "Apple", with: "[COMPANY X]")
                title = title.replacingOccurrences(of: "apple", with: "[COMPANY X]")
            }
            
            if title.localizedCaseInsensitiveContains("jailbreak") {
                title = title.replacingOccurrences(of: "jailbreak", with: "[CENSORED]")
                title = title.replacingOccurrences(of: "Jailbreak", with: "[CENSORED]")
            }
            
            if title.localizedCaseInsensitiveContains("jail break") {
                title = title.replacingOccurrences(of: "jail break", with: "[CENSORED]")
                title = title.replacingOccurrences(of: "Jail Break", with: "[CENSORED]")
            }
            
            if title.localizedCaseInsensitiveContains("macOS") {
                title = title.replacingOccurrences(of: "macOS", with: "[DESKTOP OS]")
            }
            
            if title.localizedCaseInsensitiveContains("OSX") {
                title = title.replacingOccurrences(of: "OSX", with: "[DESKTOP OS]")
            }
            
            if title.localizedCaseInsensitiveContains("OS X") {
                title = title.replacingOccurrences(of: "OS X", with: "[DESKTOP OS]")
            }
            
            if title.localizedCaseInsensitiveContains("iOS") {
                title = title.replacingOccurrences(of: "iOS", with: "[MOBILE OS]")
            }
            
            managedEvent.title = title
        } else {
            managedEvent.title = "TBD"
        }
        
        if let link = event["link"] as? String {
            managedEvent.link = link
        } else {
            managedEvent.link = ""
        }
        
        if let location = event["location"] as? String {
            managedEvent.location = location
        } else {
            managedEvent.location = ""
        }
        
        if let entryType = event["entry_type"] as? String {
            managedEvent.entry_type = entryType
        } else {
            managedEvent.entry_type = ""
        }
        
        if var description = event["description"] as? String {
            if description.localizedCaseInsensitiveContains("Apple") {
                description = description.replacingOccurrences(of: "Apple", with: "[COMPANY X]")
                description = description.replacingOccurrences(of: "apple", with: "[COMPANY X]")
            }
            
            if description.localizedCaseInsensitiveContains("watchOS") {
                description = description.replacingOccurrences(of: "watchOS", with: "[OPERATING SYSTEM]")
            }
            
            if description.localizedCaseInsensitiveContains("macOS") {
                description = description.replacingOccurrences(of: "macOS", with: "[DESKTOP OPERATING SYSTEM]")
            }
            
            if description.localizedCaseInsensitiveContains("OSX") {
                description = description.replacingOccurrences(of: "OSX", with: "[DESKTOP OPERATING SYSTEM]")
            }
            
            if description.localizedCaseInsensitiveContains("OS X") {
                description = description.replacingOccurrences(of: "OS X", with: "[DESKTOP OPERATING SYSTEM]")
            }
            
            if description.localizedCaseInsensitiveContains("iOS") {
                description = description.replacingOccurrences(of: "iOS", with: "[MOBILE OPERATING SYSTEM]")
            }
            
            if description.localizedCaseInsensitiveContains("jailbreak") {
                description = description.replacingOccurrences(of: "jailbreak", with: "[CENSORED]")
                description = description.replacingOccurrences(of: "Jailbreak", with: "[CENSORED]")
            }
            
            if description.localizedCaseInsensitiveContains("jail break") {
                description = description.replacingOccurrences(of: "jail break", with: "[CENSORED]")
                description = description.replacingOccurrences(of: "Jail Break", with: "[CENSORED]")
            }
            
            managedEvent.details = description
        } else {
            managedEvent.details = ""
        }
        
        if let startDateString = event["start_date"] as? String, let startDate =  DateFormatterUtility.iso8601Formatter.date(from: startDateString) {
            //print("startdate: \(String(describing:startDateString))")
            managedEvent.start_date = startDate
        } else {
            managedEvent.start_date = DateFormatterUtility.iso8601Formatter.date(from: "2018-01-19T10:00:00-05:00")!
        }
        
        if let endDateString = event["end_date"] as? String, let endDate =  DateFormatterUtility.iso8601Formatter.date(from: endDateString) {
            managedEvent.end_date = endDate
        } else {
            managedEvent.end_date = DateFormatterUtility.iso8601Formatter.date(from: "2018-01-21T10:00:00-05:00")!
        }
        
        if let lastUpdateString = event["last_update"] as? String, let lastUpdateDate =  DateFormatterUtility.iso8601Formatter.date(from: lastUpdateString) {
            managedEvent.updated_at = lastUpdateDate
        } else {
            managedEvent.updated_at = Date()
        }
        
        if let recommendedString = event["recommended"] as? String, let recommendedInt = Int(recommendedString) {
            managedEvent.recommended = recommendedInt == 1
        } else {
            managedEvent.recommended = false
        }
                
        try managedContext.save()
        
        return managedEvent
    }
    
    public func deleteMessages() throws {
        let frm:NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Message")
        
        let ret = try managedContext.fetch(frm) as? [Message]
        
        for msg in ret! {
            managedContext.delete(msg)
        }
    }
    
    public func resetDB() throws {
        let fre:NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Event")
        let frs:NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Speaker")
        
        let rete = try managedContext.fetch(fre) as? [Event]
        for ev in rete! {
            managedContext.delete(ev)
        }
        let rets = try managedContext.fetch(frs) as? [Speaker]
        for sp in rets! {
            managedContext.delete(sp)
        }
        
    }
    
    public func importMessages(msgData : Data) throws {
        let _messages = try JSONSerialization.jsonObject(with: msgData, options: .allowFragments) as? [String : Any]
        
        guard let messages = _messages, let updateDateString = messages["update_date"] as? String, let messageItems = messages["messages"] as? [[String : Any]] else
        {
            return ;
        }
        
        for msg in messageItems
        {
            if let _ = msg["date"] as? String, let _ = msg["text"] as? String, let _ = msg["id"] as? String {
                do {
                    _ = try importMessage(msg: msg)
                } catch let error {
                    print("Failed to import message \(msg) error \(error)")
                }
            }
        }
    }
    
    public func importMessage(msg: [String : Any]) throws -> Message {
        guard let id = msg["id"] as? String else {
            throw ImportError.idDoesntExist
        }
        
        print("import message \(id)")

        let frm:NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Message")
        frm.predicate = NSPredicate(format: "id = %@", argumentArray: [id])
        
        let ret = try managedContext.fetch(frm)
        
        let managedMessage : Message
        
        if let existingMessage = ret.first as? Message {
            managedMessage = existingMessage
        } else {
            managedMessage = NSEntityDescription.insertNewObject(forEntityName: "Message", into: managedContext) as! Message
            managedMessage.id = id
        }
        
        if let dateString = msg["date"] as? String, let msgDate =  DateFormatterUtility.iso8601Formatter.date(from: dateString) {
            managedMessage.date = msgDate
        } else {
            managedMessage.date = Date()
        }
        
        if let text = msg["text"] as? String {
            managedMessage.msg = text
        } else {
            managedMessage.msg = ""
        }
        
        return managedMessage
    }
    
    public func lastSyncDate() -> Date? {
        let fr:NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Status")
       
        let ret : [Any]
        
        do {
            ret = try managedContext.fetch(fr)
        } catch {
            return nil
        }
        
        if (ret.count > 0) {
            return (ret[0] as! Status).lastsync
        }
        
        return nil
    }
    
    func setSyncDate(_ date: Date) throws {
        
        let fr:NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Status")
        let ret = try managedContext.fetch(fr)
        
        let managedStatus : Status
        
        if let firstStatus = ret.first as? Status {
            managedStatus = firstStatus
        } else {
            managedStatus = NSEntityDescription.insertNewObject(forEntityName: "Status", into: managedContext) as! Status
        }
        
        managedStatus.lastsync = date

        try managedContext.save()
    }
    
    func setSpeakerEventPair(eventID : Int32, speakerID : Int32) throws {
        let speakersFetch:NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"EventSpeaker")
        speakersFetch.predicate = NSPredicate(format: "index = %@ AND indexsp = %@", argumentArray: [eventID,speakerID])
        
        do {
            let speakerEvents = try managedContext.fetch(speakersFetch) as? [EventSpeaker]
            
            if (speakerEvents?.count)! < 1 {
                //print("Adding speaker \(speakerID) to event \(eventID)")
                let eventSpeaker = NSEntityDescription.insertNewObject(forEntityName: "EventSpeaker", into: managedContext) as! EventSpeaker
                
                eventSpeaker.index = eventID
                eventSpeaker.indexsp = speakerID
            }
            
            try managedContext.save()
        } catch {
            assert(false, "Couldn't Fetch Speakers")
            print("Couldn't fetch speakers ignoring")
        }

    }
    
}
