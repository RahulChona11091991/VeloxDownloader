//
//  VeloxDownloadManager.swift
//  VeloxDownloader
//
//  Created by Nitin Sharma on 11/28/16.
//  Copyright © 2016 Nitin Sharma. All rights reserved.
//

import Foundation
import CoreGraphics
import UserNotifications


public protocol DownloadManagerDelegate {
    func downloadItemAdded(downloadInstance : VeloxDownloadInstance)
    func downloadItemRemoved(downloadInstance : VeloxDownloadInstance)
    
}

public class VeloxDownloadManager : NSObject,URLSessionDelegate,URLSessionDownloadDelegate,UNUserNotificationCenterDelegate
    
{
    
    public var currentDownloads : Array<String>?
    public var backgroundTransferCompletionHandler :( () -> ())?
    public var session : URLSession?
    public var backgroundSession : URLSession?
    public  static var downloadInstanceDictionary : Dictionary<String, VeloxDownloadInstance>?
    
    public var delegate : DownloadManagerDelegate?
    
    public static let sharedInstance = VeloxDownloadManager()
    
    override private init() {
        
        super.init()
        let configuration = URLSessionConfiguration.default
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        let backgroundConfiguration  = URLSessionConfiguration.background(withIdentifier: "com.sharmanitin.VeloxDownloader")
        self.backgroundSession = URLSession(configuration: backgroundConfiguration, delegate: self, delegateQueue: nil)
        self.currentDownloads = Array<String>()
        VeloxCacheManagement.cleanTempDirectory()
        UNUserNotificationCenter.current().delegate = self
        
    }
    
    
    public func downloadFileWithVeloxDownloader(
        withURL: URL,
        name : String,
        directoryName:String?,
        friendlyName : String?,
        backgroundingMode :Bool
        
        ) -> Void {
        
        if(VeloxDownloadManager.downloadInstanceDictionary == nil)
        {
            VeloxDownloadManager.downloadInstanceDictionary = Dictionary<String,VeloxDownloadInstance>()
        }
        
        if(VeloxCacheManagement.fileExistForURL(url: withURL))
        {
            let result =  VeloxCacheManagement.deleteFileForURL(url: withURL)
            print("file1 got deleted : \(result)")
        }
        
        //Do the Session networking here
        var fileName  = name
        let url  = withURL
        var friendlyName = friendlyName
        var directoryName = directoryName
        
        if (fileName.isEmpty) {
            fileName = withURL.lastPathComponent
        }
        
        if (friendlyName == nil) {
            friendlyName = fileName;
        }
        
        if (directoryName == nil)
        {
            directoryName = VeloxCacheManagement.cachesDirectoryURlPath().appendingPathComponent(name).absoluteString
        }
        
        if(VeloxCacheManagement.fileDownloadCompletedForURL(url: url))
        {
            print("file is finished downloading")
        }
        else if(!(VeloxCacheManagement.fileExistForURL(url: url, directory: directoryName)))
        {
            
            let request = URLRequest(url: url)
            let downloadTask : URLSessionDownloadTask
            if(backgroundingMode)
            {
                downloadTask = self.backgroundSession!.downloadTask(with: request)
            }
            else
            {
                downloadTask  = self.session!.downloadTask(with: request)
            }
            
            let downloadInstance = VeloxDownloadInstance(withDownloadTask: downloadTask, remainingTime: nil, progess: nil, status: nil, name: fileName, friendlyName: friendlyName!, path: directoryName!, date: Date())
            
            VeloxDownloadManager.downloadInstanceDictionary![url.lastPathComponent] = downloadInstance
            if(delegate != nil)
            {
                delegate?.downloadItemAdded(downloadInstance: downloadInstance)
            }
            
            downloadTask.resume()
            
            
        }
        else
        {
            print("file already exists")
            
        }
        
    }
    
    public func downloadFile(
        withURL: URL,
        name : String,
        directoryName:String?,
        friendlyName : String?,
        progressClosure : @escaping ((CGFloat,VeloxDownloadInstance)->(Void)),
        remainigtTimeClosure : @escaping ((CGFloat)->(Void)),
        completionClosure : @escaping ((Bool, String?, Error?)->(Void)),
        backgroundingMode :Bool
        
        ) -> Void {
        
        if(VeloxDownloadManager.downloadInstanceDictionary == nil)
        {
            VeloxDownloadManager.downloadInstanceDictionary = Dictionary<String,VeloxDownloadInstance>()
        }
        
        if(VeloxCacheManagement.fileDownloadCompletedForURL(url: withURL))
        {
            print("file is finished downloading")
            if(VeloxCacheManagement.fileExistForURL(url: withURL))
            {
                let result =  VeloxCacheManagement.deleteFileForURL(url: withURL)
                print("file1 got deleted : \(result)")
            }
            
        }
        
        
        //Do the Session networking here
        var fileName  = name
        let url  = withURL
        var friendlyName = friendlyName
        var directoryName = directoryName
        
        if (fileName.isEmpty) {
            fileName = withURL.lastPathComponent
        }
        
        if (friendlyName == nil) {
            friendlyName = fileName;
        }
        
        if (directoryName == nil)
        {
            directoryName = VeloxCacheManagement.cachesDirectoryURlPath().appendingPathComponent(name).absoluteString
        }
        
        if(VeloxCacheManagement.fileDownloadCompletedForURL(url: url))
        {
            print("file is finished downloading")
        }
        else if(!(VeloxCacheManagement.fileExistForURL(url: url, directory: directoryName)))
        {
            
            let request = URLRequest(url: url)
            let downloadTask : URLSessionDownloadTask
            if(backgroundingMode)
            {
                downloadTask = self.backgroundSession!.downloadTask(with: request)
            }
            else
            {
                downloadTask  = self.session!.downloadTask(with: request)
            }
            
            let downloadInstance = VeloxDownloadInstance(withDownloadTask: downloadTask, remainingTime: remainigtTimeClosure, progess: progressClosure, status: completionClosure, name: fileName, friendlyName: friendlyName!, path: directoryName!, date: Date())
            
            VeloxDownloadManager.downloadInstanceDictionary![url.lastPathComponent] = downloadInstance
            
            
            downloadTask.resume()
            
            
        }
        else
        {
            print("file already exists")
            
            //print("data written \(totalBytesWritten)")
            let fileIdentifier  = url.lastPathComponent
            let dowloadInstace = VeloxDownloadManager.downloadInstanceDictionary![fileIdentifier]
            
            DispatchQueue.main.async {
                completionClosure(true, "File already exists:\(url.lastPathComponent)" , nil)
            }
        }
        
    }
    
    
    
    //MARK : Session
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }

        
        //print("data written \(totalBytesWritten)")
        let fileIdentifier  = downloadTask.originalRequest!.url!.lastPathComponent
        let dowloadInstace = VeloxDownloadManager.downloadInstanceDictionary![fileIdentifier]
        let  progress = CGFloat.init(totalBytesWritten) / CGFloat.init(totalBytesExpectedToWrite)
        
        debugPrint("progress is   \(progress)")
        print("progress is   \(progress)")
        
        DispatchQueue.main.async {
            dowloadInstace!.currentProgressClosure!(CGFloat(progress),dowloadInstace!)
        }
        
        let remainingTime = self.remainingTimeForDownload(downloadInstace: dowloadInstace!, totalBytesTransferred: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        
        
        DispatchQueue.main.async {
            dowloadInstace!.remainingTimeClosure! (remainingTime)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        
        debugPrint("Download finished: \(location)")
        print("Download finished: \(location)")
        
        let fileIdentifier  = downloadTask.originalRequest!.url!.lastPathComponent
        let dowloadInstace = VeloxDownloadManager.downloadInstanceDictionary![fileIdentifier]
        var destinationLocation : URL  = VeloxCacheManagement.cachesDirectoryURlPath()
        
        if(dowloadInstace!.filePath.isEmpty){
            destinationLocation = destinationLocation.appendingPathComponent(fileIdentifier)
        }
        else{
            
            destinationLocation = URL(string: dowloadInstace!.filePath)!
        }
        
        var success = true
        
        let response  = downloadTask.response! as! HTTPURLResponse
        let statusCode = response.statusCode
        
        if (statusCode >= 400) {
            success = false
        }
        
        
        if (success) {
            
            
            if(delegate != nil)
            {
                delegate?.downloadItemRemoved(downloadInstance: dowloadInstace!)
            }
            do
            {
                if(VeloxCacheManagement.fileExistWithName(name: dowloadInstace!.filename))
                    
                {
                    try  FileManager.default.removeItem(at: destinationLocation)
                    
                }
                try  FileManager.default.moveItem(at: location, to: destinationLocation)
                dowloadInstace?.downloadStatusClosure!(true, "Download Completed:\(dowloadInstace!.filename)" , nil)
            }
            catch let error as NSError
            {
                print("error occured \(error.localizedDescription)")
                dowloadInstace?.downloadStatusClosure!(false, error.localizedDescription , error)
            }
            VeloxDownloadManager.downloadInstanceDictionary!.removeValue(forKey: dowloadInstace!.filename)
            //            dowloadInstace!.downloadStatusClosure!(true)
        } else {
            dowloadInstace?.downloadStatusClosure!(false, "Something went wrong" , NSError(domain: "Something went wrong", code: statusCode, userInfo: nil))
        }
        
        
        //do a local notification
    }
    
    
    
   public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        debugPrint("Task completed: \(task), error: \(error)")
        print("Task completed: \(task), error: \(error)")
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
    
    public func remainingTimeForDownload(downloadInstace : VeloxDownloadInstance, totalBytesTransferred : Int64,totalBytesExpectedToWrite : Int64) -> CGFloat {
        
        let timeInterval : TimeInterval  = Date().timeIntervalSince(downloadInstace.downloadDate)
        
        let speed  = CGFloat.init(totalBytesTransferred) / CGFloat.init(timeInterval)
        let remainingBytes = totalBytesExpectedToWrite - totalBytesTransferred
        let remainingTime = CGFloat.init(remainingBytes) / CGFloat.init(speed)
        return  remainingTime
    }
    
    
    
    
    
    
    
    //MARK : Finish Session
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        
        session.getAllTasks { (taskArray) in
            if(taskArray.count == 0)
            {
                if(self.backgroundTransferCompletionHandler != nil)
                {
                    let completer = self.backgroundTransferCompletionHandler
                    
                    OperationQueue().addOperation(
                        completer!
                    )
                    
                    self.backgroundTransferCompletionHandler = nil;
                    
                }
            }
        }
    }
    
    
    
    
    
}
