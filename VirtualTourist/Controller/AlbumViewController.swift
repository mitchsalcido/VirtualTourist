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
    var flickrAnnotation:FlickrAnnotation!

    var flickFetchedResultsController:NSFetchedResultsController<Flick>!
    var albumFetchedResultsController:NSFetchedResultsController<Album>!
    var dataController:CoreDataController!
    
    var flicksToDeleteIndexPaths:Set<IndexPath> = []
    let defaultImage:UIImage = UIImage(imageLiteralResourceName: "DefaultImage")
    
    let CellsPerRow:CGFloat = 5.0
    let CellSpacing:CGFloat = 5.0
    
    enum UIState {
        case editing
        case preDownloading
        case downloading
        case normal
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        dataController = appDelegate.dataController
        
        flowLayout.minimumLineSpacing = CellSpacing
        flowLayout.minimumInteritemSpacing = CellSpacing
        
        navigationItem.rightBarButtonItem = editButtonItem
        title = flickrAnnotation.title
        
        configFlickFRC()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        flowLayout.invalidateLayout()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        flicksToDeleteIndexPaths.removeAll()
        
        if editing {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashBbiPressed(sender:)))
            navigationItem.leftBarButtonItem?.isEnabled = false
            updateUI(state: .editing)
        } else {
            updateUI(state: .normal)
        }
        
        collectionView.reloadData()
    }
    
    fileprivate func configFlickFRC() {
        
        let fetchRequest:NSFetchRequest<Flick> = NSFetchRequest(entityName: "Flick")
        let sortDescriptor = NSSortDescriptor(key: "urlString", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        flickFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        flickFetchedResultsController.delegate = self
        do {
            try flickFetchedResultsController.performFetch()
        } catch {
            showOKAlert(error: error)
        }
    }
    
    fileprivate func configAlbumFRC() {
        
        let fetchRequest:NSFetchRequest<Album> = NSFetchRequest(entityName: "Album")
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        let predicate = NSPredicate(format: "name = %@",)
        albumFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        albumFetchedResultsController.delegate = self
        do {
            try albumFetchedResultsController.performFetch()
        } catch {
            showOKAlert(error: error)
        }
    }
    
    @IBAction func reloadBbiPressed(_ sender: Any) {

        let alert = UIAlertController(title: "Load New Album ?", message: "Existing phots will be deleted.", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let proceedAction = UIAlertAction(title: "Proceed", style: .destructive) { action in
            
            if let flicks = self.flickrAnnotation.album.flicks?.allObjects as? [Flick] {
                self.dataController.deleteManagedObjects(objects: flicks) { error in
                                                  
                    if error == nil {
                        self.collectionView.reloadData()
                        self.updateUI(state: .preDownloading)
                        self.dataController.reloadAlbum(album: self.flickrAnnotation.album) { error in
                            self.updateUI(state: .normal)
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
        case .preDownloading:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = false
            reloadBbi.isEnabled = false
            activityIndicator.startAnimating()
        case .downloading:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = false
            reloadBbi.isEnabled = false
            activityIndicator.stopAnimating()
        case .normal:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = true
            reloadBbi.isEnabled = true
            activityIndicator.stopAnimating()
        }
    }
}

// MARK: BarButtonItem Actions
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
}

extension AlbumViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "FlickDetailSegueID" {
            let controller = segue.destination as! FlickDetailViewController
            controller.flick = sender as? Flick
        }
    }
}

extension AlbumViewController {

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
       
        if !flicksToDeleteIndexPaths.isEmpty {
            collectionView.performBatchUpdates {
                self.collectionView.deleteItems(at: Array(flicksToDeleteIndexPaths))
            }
            setEditing(false, animated: false)
        }
        
        if !flickrAnnotation.album.flickDownloadComplete {
            print("not complete")
            updateUI(state: .downloading)
        } else {
            print("complete")
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        if type == .update {
            if let indexPath = indexPath {
                collectionView.reloadItems(at: [indexPath])
            }
        }
    }
}
