//
//  HTScheduleTableViewController.swift
//  hackertracker
//
//  Created by Seth Law on 4/15/15.
//  Copyright (c) 2015 Beezle Labs. All rights reserved.
//

import UIKit
import CoreData

class BaseScheduleTableViewController: UITableViewController {
    
    var eventSections : [[Event]] = []
    var syncAlert = UIAlertController(title: nil, message: "Syncing...", preferredStyle: .alert)
    var data = NSMutableData()

    // TODO: Update for DC 25
    var days = ["2016-08-04", "2016-08-05", "2016-08-06", "2016-08-07"];
    
    func sync(sender: AnyObject) {
        
        let envPlist = Bundle.main.path(forResource: "Connections", ofType: "plist")
        let envs = NSDictionary(contentsOfFile: envPlist!)!
        
        let tURL = envs.value(forKey: "URL") as! String
        //NSLog("Connecting to \(tURL)")
        let URL = Foundation.URL(string: tURL)
        
        var request = URLRequest(url: URL!)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            
            if let error = error {
                NSLog("DataTsk error: " + error.localizedDescription)
            } else {
                NSLog("Made it here")
                let resStr = NSString(data: data!, encoding: String.Encoding.ascii.rawValue)
            
                let dataFromString = resStr!.data(using: String.Encoding.utf8.rawValue)
            
                let n = DateFormatterUtility.monthDayTimeFormatter.string(from: Date())
                let attr: Dictionary = [ NSForegroundColorAttributeName : UIColor.white ]

                if (updateSchedule(dataFromString!)) {
                    self.refreshControl?.attributedTitle = NSAttributedString(string: "Updated \(n)", attributes: attr)
                } else {
                    self.refreshControl?.attributedTitle = NSAttributedString(string: "Last sync at \(n)", attributes: attr)
                }
            
                self.refreshControl?.endRefreshing()
            }
        }).resume()
        //var queue = OperationQueue()
        //var con = NSURLConnection(request: request as URLRequest, delegate: self, startImmediately: true)

    }
    
    /*func connection(_ con: NSURLConnection!, didReceiveData _data:Data!) {
        self.data.append(_data)
    }
    
    func connectionDidFinishLoading(_ con: NSURLConnection!) {
        
        let resStr = NSString(data: self.data as Data, encoding: String.Encoding.ascii.rawValue)
        
        let dataFromString = resStr!.data(using: String.Encoding.utf8.rawValue)
        
        let df = DateFormatter()
        df.dateFormat = "dd/MM HH:mm"
        df.locale = Locale(identifier: "en_US_POSIX")
        let n = df.string(from: Date())
        let attr: Dictionary = [ NSForegroundColorAttributeName : UIColor.white ]
        
        if (updateSchedule(dataFromString!)) {
            refreshControl?.attributedTitle = NSAttributedString(string: "Updated \(n)", attributes: attr)
        } else {
            refreshControl?.attributedTitle = NSAttributedString(string: "Sync at \(n)", attributes: attr)
        }
        
        refreshControl?.endRefreshing()
    }*/

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(EventCell.self, forCellReuseIdentifier: "Events")
        
        refreshControl = UIRefreshControl()
        let attr: Dictionary = [ NSForegroundColorAttributeName : UIColor.white ]
        refreshControl?.attributedTitle = NSAttributedString(string: "Sync", attributes: attr)
        refreshControl?.tintColor = UIColor.gray
        refreshControl?.addTarget(self, action: #selector(self.sync(sender:)), for: UIControlEvents.valueChanged)
        tableView.addSubview(refreshControl!)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadEvents()
    }
    
    fileprivate func reloadEvents() {
        eventSections.removeAll()

        for day in days {
            eventSections.append(RetrieveEventsForDay(day).map { (object) -> Event in
                return object as! Event
                })
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return days.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard eventSections.count > section else {
            return 0;
        }
        
        return self.eventSections[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "eventCell", for: indexPath) as! EventCell
        let event : Event = self.eventSections[indexPath.section][indexPath.row]

        cell.bind(event: event)
        
        return cell
    }

    func RetrieveEventsForDay(_ dateString: String) -> [AnyObject] {
        let delegate : AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = delegate.managedObjectContext!

        return try! context.fetch(fetchRequestForDay(dateString))
    }

    func fetchRequestForDay(_ dateString: String) -> NSFetchRequest<NSFetchRequestResult> {

        let startofDay: Date = DateFormatterUtility.yearMonthDayTimeFormatter.date(from: "\(dateString) 00:00:00 PDT")!
        let endofDay: Date =  DateFormatterUtility.yearMonthDayTimeFormatter.date(from: "\(dateString) 23:59:59 PDT")!

        let fr = NSFetchRequest<NSFetchRequestResult>(entityName:"Event")
        fr.predicate = NSPredicate(format: "begin >= %@ AND end <= %@", argumentArray: [ startofDay, endofDay])
        fr.sortDescriptors = [NSSortDescriptor(key: "begin", ascending: true)]
        fr.returnsObjectsAsFaults = false

        return fr
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return days[section]
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "eventDetailSegue") {
            let dv : HTEventDetailViewController = segue.destination as! HTEventDetailViewController
            var indexPath: IndexPath
            if let ec = sender as? EventCell {
                indexPath = tableView.indexPath(for: ec)! as IndexPath
            } else {
                indexPath = sender as! IndexPath
            }
            dv.event = self.eventSections[indexPath.section][indexPath.row]
        }
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {

        let favorite = UITableViewRowAction(style: .normal, title: "Favorite") { (action, indexpath) in

        }
        favorite.backgroundColor = UIColor(red: 0.0/255.0, green: 100.0/255.0, blue: 0.0/255.0, alpha: 1.0)

        return [favorite]
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {

    }
}

class HTScheduleTableViewController: BaseScheduleTableViewController, UISearchBarDelegate {
    var eType : eventType!
    let searchBar = UISearchBar()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.title = eType.name
    }

    override func fetchRequestForDay(_ dateString: String) -> NSFetchRequest<NSFetchRequestResult> {
        let startofDay: Date =  DateFormatterUtility.yearMonthDayTimeFormatter.date(from: "\(dateString) 00:00:00 PDT")!
        let endofDay: Date =  DateFormatterUtility.yearMonthDayTimeFormatter.date(from: "\(dateString) 23:59:59 PDT")!

        let fr = NSFetchRequest<NSFetchRequestResult>(entityName:"Event")
        fr.predicate = NSPredicate(format: "type = %@ AND begin >= %@ AND end <= %@", argumentArray: [eType.dbName, startofDay, endofDay])
        fr.sortDescriptors = [NSSortDescriptor(key: "begin", ascending: true)]
        fr.returnsObjectsAsFaults = false

        return fr
    }
}



