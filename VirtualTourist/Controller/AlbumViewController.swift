//
//  AlbumCollectionViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

import UIKit
import CoreLocation
import CoreData

private let reuseIdentifier = "AlbumCellID"

class AlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, NSFetchedResultsControllerDelegate {
            
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var reloadBbi: UIBarButtonItem!
    var album:Album!
    var pin:Pin!
    
    var flickFetchedResultsController:NSFetchedResultsController<Flick>!
    var albumFetchedResultsController:NSFetchedResultsController<Album>!
    var dataController:CoreDataController!
    
    var flicksToDeleteIndexPaths:Set<IndexPath> = []
    let defaultImage:UIImage = UIImage(imageLiteralResourceName: "DefaultImage")
    var downloadedFlickCount:Int = 0
    
    let CellsPerRow:CGFloat = 5.0
    let CellSpacing:CGFloat = 5.0
    
    enum UIState {
        case editing
        case preDownloading
        case downloading
        case normal
        case noFlicksFound
        case emptyAlbum
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        dataController = appDelegate.dataController
        
        flowLayout.minimumLineSpacing = CellSpacing
        flowLayout.minimumInteritemSpacing = CellSpacing
        
        navigationItem.rightBarButtonItem = editButtonItem
        editButtonItem.isEnabled = false
        reloadBbi.isEnabled = false
        title = album.name
        
        configFlickFRC()
        configAlbumFRC()
        
        downloadedFlickCount = album.downloadedFlickImageCount()
        let zeroCount = (downloadedFlickCount == 0)
        
        /*
         Album state logic for initial UIState
         noFlicksFound  downloadComplete    zeroCount       UIState         Alert
         false              false                true        .downloading    x
         false              true                 true        .normal         handleEmptyAlbum
         true               x                    x           .noFlicksFound  handleNoFlicksFound
         true               x                    x           .noFlicksFound  handleNoFlicksFound
         false              false                false       .downloading    x
         false              true                 false       .normal         x
         true               x                    x           .noFlicksFound  handleNoFlicksFound
         true               x                    x           .noFlicksFound  handleNoFlicksFound
         */
        if album.noFlicksFound {
            updateUI(state: .noFlicksFound)
            perform(#selector(handleNoFlicksFound), with: nil, afterDelay: 1.0)
        } else if !album.noFlicksFound && album.flickDownloadComplete && zeroCount {
            updateUI(state: .emptyAlbum)
            perform(#selector(handleEmptyAlbum), with: nil, afterDelay: 1.0)
        } else if !album.noFlicksFound && album.flickDownloadComplete && !zeroCount {
            updateUI(state: .normal)
        } else if !album.noFlicksFound && !album.flickDownloadComplete {
            updateUI(state: .downloading)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        flowLayout.invalidateLayout()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        flicksToDeleteIndexPaths.removeAll()
        
        if editing {
            updateUI(state: .editing)
        } else {
            updateUI(state: .normal)
        }
        
        collectionView.reloadData()
    }
}

// MARK: UICollectionViewDataSource
extension AlbumViewController {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return flickFetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! AlbumCollectionViewCell
    
        let flick = flickFetchedResultsController.object(at: indexPath)
        
        
        if let imageData = flick.imageData {
            cell.imageView.image = UIImage(data: imageData)
            cell.activityIndicator.stopAnimating()
        } else {
            cell.imageView.image = defaultImage
            cell.activityIndicator.startAnimating()
        }
        
        cell.imageView.alpha = isEditing ? 0.75 : 1.0
        cell.checkmarkImageView.isHidden = flicksToDeleteIndexPaths.contains(indexPath) ? false : true

        return cell
    }
}

// MARK: UICollectionViewDelegate
extension AlbumViewController {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if self.isEditing {
            
            if flicksToDeleteIndexPaths.contains(indexPath) {
                flicksToDeleteIndexPaths.remove(indexPath)
            } else {
                flicksToDeleteIndexPaths.insert(indexPath)
            }
            
            navigationItem.leftBarButtonItem?.isEnabled = !flicksToDeleteIndexPaths.isEmpty
            collectionView.reloadItems(at: [indexPath])
            
            return
        }
    
        let flick = flickFetchedResultsController.object(at: indexPath)
        if flick.imageData != nil {
            performSegue(withIdentifier: "FlickDetailSegueID", sender:flick)
        }
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension AlbumViewController {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let size = collectionView.bounds.width - (CellsPerRow - 1.0) * CellSpacing
        return CGSize(width: size / CellsPerRow, height: size / CellsPerRow)
    }
}

// MARK: BarButtonItem Target/Actions
extension AlbumViewController {
    
    @objc func trashBbiPressed(sender: UIBarButtonItem) {
        
        var flicksToDelete:[Flick] = []
        for indexPath in flicksToDeleteIndexPaths {
            let flick = flickFetchedResultsController.object(at: indexPath)
            flicksToDelete.append(flick)
        }
        
        dataController.deleteManagedObjects(objects: flicksToDelete) { error in
            if let error = error {
                self.showOKAlert(error: error)
            }
        }
    }
    
    @IBAction func reloadBbiPressed(_ sender: Any) {

        let alert = UIAlertController(title: "Load New Album ?", message: "Existing phots will be deleted.", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let proceedAction = UIAlertAction(title: "Proceed", style: .destructive) { action in
            
            if let flicks = self.album.flicks?.allObjects as? [Flick] {
                
                self.dataController.deleteManagedObjects(objects: flicks) { error in
                    if let error = error {
                        self.showOKAlert(error: error)
                    } else {
                        self.collectionView.reloadData()
                        self.updateUI(state: .preDownloading)
                        self.dataController.reloadAlbum(album: self.album) { error in
                            if let error = error {
                                self.showOKAlert(error: error)
                            }
                        }
                    }
                }
            }
        }
        alert.addAction(proceedAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
}

// MARK: Segue
extension AlbumViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "FlickDetailSegueID" {
            let controller = segue.destination as! FlickDetailViewController
            controller.flick = sender as? Flick
        }
    }
}

// MARK: FetchedResultsController Delegate
extension AlbumViewController {

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
       
        if controller == flickFetchedResultsController {
            if !flicksToDeleteIndexPaths.isEmpty {
                collectionView.performBatchUpdates {
                    self.collectionView.deleteItems(at: Array(flicksToDeleteIndexPaths))
                }
                setEditing(false, animated: false)
            }
        }
        
        if controller == albumFetchedResultsController {
            if album.flickDownloadComplete {
                if let empty = flickFetchedResultsController.fetchedObjects?.isEmpty, empty == true {
                    updateUI(state: .emptyAlbum)
                } else {
                    updateUI(state: .normal)
                }
                progressView.progress = 0.0
            } else {
                downloadedFlickCount = album.downloadedFlickImageCount()
            }
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        if controller == flickFetchedResultsController {
            if type == .update {
                if let indexPath = indexPath {
                    collectionView.reloadItems(at: [indexPath])
                    
                    downloadedFlickCount += 1
                    let total = album.flicks?.count ?? 1
                    progressView.progress = Float(downloadedFlickCount) / Float(total)
                    
                    if (total > 1) && (downloadedFlickCount == 1) {
                        updateUI(state: .downloading)
                    }
                }
            }
        }
    }
}

// MARK: Helpers
extension AlbumViewController {
    
    func updateUI(state: UIState) {
        
        switch state {
        case .editing:
            let bbi = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashBbiPressed(sender:)))
            navigationItem.leftBarButtonItem = bbi
            navigationItem.leftBarButtonItem?.isEnabled = false
            reloadBbi.isEnabled = false
            activityIndicator.stopAnimating()
            progressView.isHidden = true
        case .preDownloading:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = false
            reloadBbi.isEnabled = false
            activityIndicator.startAnimating()
            progressView.isHidden = true
        case .downloading:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = false
            reloadBbi.isEnabled = false
            activityIndicator.stopAnimating()
            progressView.isHidden = false
        case .normal:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = true
            reloadBbi.isEnabled = true
            activityIndicator.stopAnimating()
            progressView.isHidden = true
        case .noFlicksFound:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = false
            reloadBbi.isEnabled = false
            activityIndicator.stopAnimating()
            progressView.isHidden = true
        case .emptyAlbum:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = false
            reloadBbi.isEnabled = true
            activityIndicator.stopAnimating()
            progressView.isHidden = true
        }
    }
    
    fileprivate func configFlickFRC() {
        
        let fetchRequest:NSFetchRequest<Flick> = NSFetchRequest(entityName: "Flick")
        let sortDescriptor = NSSortDescriptor(key: "urlString", ascending: false)
        let predicate = NSPredicate(format: "album = %@", album)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.predicate = predicate
        flickFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        flickFetchedResultsController.delegate = self
        do {
            try flickFetchedResultsController.performFetch()
        } catch {
            showOKAlert(error: CoreDataController.CoreDataError.badFetch)
        }
    }
    
    fileprivate func configAlbumFRC() {
        
        let fetchRequest:NSFetchRequest<Album> = NSFetchRequest(entityName: "Album")
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        let predicate = NSPredicate(format: "name = %@", album.name!)
        fetchRequest.predicate = predicate
        albumFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        albumFetchedResultsController.delegate = self
        do {
            try albumFetchedResultsController.performFetch()
        } catch {
            showOKAlert(error: CoreDataController.CoreDataError.badFetch)
        }
    }
    
    @objc func handleEmptyAlbum() {
        showOKAlert(title: "Empty Album", message: "Press reload to download new Flick album.")
    }
    
    @objc func handleNoFlicksFound() {
        showOKAlert(title: "No Flicks Found", message: "Unable to locate flicks in this geographic region.")
    }
}
