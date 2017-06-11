//
//  HTEventDetailViewController.swift
//  hackertracker
//
//  Created by Seth Law on 4/17/15.
//  Copyright (c) 2015 Beezle Labs. All rights reserved.
//

import UIKit
import CoreData

class HTEventDetailViewController: UIViewController {

    @IBOutlet weak var eventTitleLabel: UILabel!
    @IBOutlet weak var eventNameButton2: UIButton!
    @IBOutlet weak var eventNameLabel: UILabel!
    @IBOutlet weak var eventDateLabel: UILabel!
    @IBOutlet weak var eventStartTimeLabel: UILabel!
    @IBOutlet weak var eventStopTimeLabel: UILabel!
    @IBOutlet weak var eventLocationLabel: UILabel!
    @IBOutlet weak var eventDetailTextView: UITextView!
    @IBOutlet weak var eventStarredButton: UIBarButtonItem!
    @IBOutlet weak var demoImage: UIImageView!
    @IBOutlet weak var exploitImage: UIImageView!
    @IBOutlet weak var toolImage: UIImageView!
    
    var event: Event?
        
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let event = event else {
            print("HTEventDetailViewController: Event is nil")
            return
        }

        eventTitleLabel.text = event.title
        eventNameLabel.text = event.who
        eventLocationLabel.text = event.location
        eventDetailTextView.text = event.details
        
        if (event.starred) {
            eventStarredButton.image = #imageLiteral(resourceName: "saved-active")
        } else {
            eventStarredButton.image = #imageLiteral(resourceName: "saved-inactive")
        }
        
        if (event.tool) {
            toolImage.alpha = 1.0
        }
        
        if event.demo {
            demoImage.alpha = 1.0
        }
        
        if event.exploit {
            exploitImage.alpha = 1.0
        }

        let eventLabel = DateFormatterUtility.dayOfWeekMonthTimeFormatter.string(from: event.begin as Date)
        let eventEnd = DateFormatterUtility.hourMinuteTimeFormatter.string(from: event.end as Date)

        eventDateLabel.text = "\(eventLabel)-\(eventEnd)"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        eventDetailTextView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
        
    }
    
    @IBAction func toggleMySchedule(_ sender: AnyObject) {
        guard let event = event else {
            print("HTEventDetailViewController: Event is nil")
            return
        }
        
        let d_event = isDuplicateEvent(event)
        if (d_event != nil) {
            let alert : UIAlertController = UIAlertController(title: "Schedule Conflict", message: "Duplicate event(s):\n\(String(describing: d_event!))\n\nAdd \(event.title)\n to schedule?", preferredStyle: UIAlertControllerStyle.alert)
            let yesItem : UIAlertAction = UIAlertAction(title: "Yes", style: UIAlertActionStyle.default, handler: {
                (action:UIAlertAction) in
                event.starred = true
                self.eventStarredButton.image = #imageLiteral(resourceName: "saved-active")
            })
            let noItem : UIAlertAction = UIAlertAction(title: "No", style: UIAlertActionStyle.default, handler: {
                (action:UIAlertAction) in
                NSLog("No")
            })
            
            alert.addAction(yesItem)
            alert.addAction(noItem)
            
            self.present(alert, animated: true, completion: nil)
            
        } else {
        
            if (event.starred) {
                event.starred = false
                eventStarredButton.image = #imageLiteral(resourceName: "saved-inactive")
            } else {
                event.starred = true
                eventStarredButton.image = #imageLiteral(resourceName: "saved-active")
            }
        }

        self.saveContext()
    }
    
    func isDuplicateEvent(_ event: Event) -> String? {
        var res: String? = nil
        let delegate : AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = delegate.managedObjectContext!
        
        let fr = NSFetchRequest<NSFetchRequestResult>(entityName:"Event")
        fr.predicate = NSPredicate(format: "begin >= %@ AND end <= %@ AND starred == YES", argumentArray: [event.begin, event.end])
        fr.sortDescriptors = [NSSortDescriptor(key: "begin", ascending: true)]
        fr.returnsObjectsAsFaults = false
        
        let events = try! context.fetch(fr) as Array
        var first = true
        for e in events {
            if (first) {
                res = (e as! Event).title
                first = false
            } else {
                res = "\(String(describing: res!)), \((e as! Event).title)"
            }
        }
        
        return res
    }
    
    func saveContext() {
        let delegate : AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = delegate.managedObjectContext!
        var err :NSError?
        do {
            try context.save()
        } catch let error as NSError {
            err = error
        }
        if err != nil {
            NSLog("%@",err!)
        }
    }
    
    @IBAction func closeEvent(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
}
