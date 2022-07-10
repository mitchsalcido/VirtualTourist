//
//  PinViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

import UIKit
import CoreLocation
import CoreData

private let reuseIdentifier = "AlbumCellID"

class PinViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, NSFetchedResultsControllerDelegate {
            
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var reloadBbi: UIBarButtonItem!
    var pin:Pin!
    
    var photoFetchedResultsController:NSFetchedResultsController<Photo>!
    var pinFetchedResultsController:NSFetchedResultsController<Pin>!
    var dataController:CoreDataController!
    
    var photosToDeleteIndexPaths:Set<IndexPath> = []
    let defaultImage:UIImage = UIImage(imageLiteralResourceName: "DefaultImage")
    var downloadedPhotoCount:Int = 0
    
    let CellsPerRow:CGFloat = 5.0
    let CellSpacing:CGFloat = 5.0
    
    enum UIState {
        case editing
        case preDownloading
        case downloading
        case normal
        case noPhotosFound
        case emptyPin
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
        title = pin.name
        
        configPhotoFRC()
        configPinFRC()
        
        downloadedPhotoCount = pin.downloadedPhotoImageCount()
        let zeroCount = (downloadedPhotoCount == 0)
        
        if pin.noPhotosFound {
            updateUI(state: .noPhotosFound)
            perform(#selector(handleNoPhotosFound), with: nil, afterDelay: 1.0)
        } else if !pin.noPhotosFound && pin.photoDownloadComplete && zeroCount {
            updateUI(state: .emptyPin)
            perform(#selector(handleEmptyPin), with: nil, afterDelay: 1.0)
        } else if !pin.noPhotosFound && pin.photoDownloadComplete && !zeroCount {
            updateUI(state: .normal)
        } else if !pin.noPhotosFound && !pin.photoDownloadComplete {
            updateUI(state: .downloading)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        flowLayout.invalidateLayout()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        photosToDeleteIndexPaths.removeAll()
        
        if editing {
            updateUI(state: .editing)
        } else {
            updateUI(state: .normal)
        }
        
        collectionView.reloadData()
    }
}

// MARK: UICollectionViewDataSource
extension PinViewController {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoFetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PhotoCollectionViewCell
    
        let photo = photoFetchedResultsController.object(at: indexPath)
        
        
        if let imageData = photo.imageData {
            cell.imageView.image = UIImage(data: imageData)
            cell.activityIndicator.stopAnimating()
        } else {
            cell.imageView.image = defaultImage
            cell.activityIndicator.startAnimating()
        }
        
        cell.imageView.alpha = isEditing ? 0.75 : 1.0
        cell.checkmarkImageView.isHidden = photosToDeleteIndexPaths.contains(indexPath) ? false : true

        return cell
    }
}

// MARK: UICollectionViewDelegate
extension PinViewController {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if self.isEditing {
            
            if photosToDeleteIndexPaths.contains(indexPath) {
                photosToDeleteIndexPaths.remove(indexPath)
            } else {
                photosToDeleteIndexPaths.insert(indexPath)
            }
            
            navigationItem.leftBarButtonItem?.isEnabled = !photosToDeleteIndexPaths.isEmpty
            collectionView.reloadItems(at: [indexPath])
            
            return
        }
    
        let photo = photoFetchedResultsController.object(at: indexPath)
        if photo.imageData != nil {
            performSegue(withIdentifier: "FlickDetailSegueID", sender:photo)
        }
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension PinViewController {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let size = collectionView.bounds.width - (CellsPerRow - 1.0) * CellSpacing
        return CGSize(width: size / CellsPerRow, height: size / CellsPerRow)
    }
}

// MARK: BarButtonItem Target/Actions
extension PinViewController {
    
    @objc func trashBbiPressed(sender: UIBarButtonItem) {
        
        var photosToDelete:[Photo] = []
        for indexPath in photosToDeleteIndexPaths {
            let photo = photoFetchedResultsController.object(at: indexPath)
            photosToDelete.append(photo)
        }
        
        dataController.deleteManagedObjects(objects: photosToDelete) { error in
            if let error = error {
                self.showOKAlert(error: error)
            }
        }
    }
    
    @IBAction func reloadBbiPressed(_ sender: Any) {

        let alert = UIAlertController(title: "Load New Album ?", message: "Existing photos will be deleted.", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let proceedAction = UIAlertAction(title: "Proceed", style: .destructive) { action in
            
            if let photos = self.pin.photos?.allObjects as? [Photo] {
                
                self.dataController.deleteManagedObjects(objects: photos) { error in
                    if let error = error {
                        self.showOKAlert(error: error)
                    } else {
                        self.collectionView.reloadData()
                        self.updateUI(state: .preDownloading)
                        self.dataController.reloadPin(pin: self.pin) { error in
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
extension PinViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "FlickDetailSegueID" {
            let controller = segue.destination as! PhotoDetailViewController
            controller.photo = sender as? Photo
        }
    }
}

// MARK: FetchedResultsController Delegate
extension PinViewController {

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
       
        if controller == photoFetchedResultsController {
            if !photosToDeleteIndexPaths.isEmpty {
                collectionView.performBatchUpdates {
                    self.collectionView.deleteItems(at: Array(photosToDeleteIndexPaths))
                }
                setEditing(false, animated: false)
            }
        }
        
        if controller == pinFetchedResultsController {
            if pin.photoDownloadComplete {
                if let empty = photoFetchedResultsController.fetchedObjects?.isEmpty, empty == true {
                    updateUI(state: .emptyPin)
                } else {
                    updateUI(state: .normal)
                }
                progressView.progress = 0.0
            } else {
                downloadedPhotoCount = pin.downloadedPhotoImageCount()
            }
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        if controller == photoFetchedResultsController {
            if type == .update {
                if let indexPath = indexPath {
                    collectionView.reloadItems(at: [indexPath])
                    
                    downloadedPhotoCount += 1
                    let total = pin.photos?.count ?? 1
                    progressView.progress = Float(downloadedPhotoCount) / Float(total)
                    
                    if (total > 1) && (downloadedPhotoCount == 1) {
                        updateUI(state: .downloading)
                    }
                }
            }
        }
    }
}

// MARK: Helpers
extension PinViewController {
    
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
        case .noPhotosFound:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = false
            reloadBbi.isEnabled = false
            activityIndicator.stopAnimating()
            progressView.isHidden = true
        case .emptyPin:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = false
            reloadBbi.isEnabled = true
            activityIndicator.stopAnimating()
            progressView.isHidden = true
        }
    }
    
    fileprivate func configPhotoFRC() {
        
        let fetchRequest:NSFetchRequest<Photo> = NSFetchRequest(entityName: "Photo")
        let sortDescriptor = NSSortDescriptor(key: "urlString", ascending: false)
        let predicate = NSPredicate(format: "pin = %@", pin)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.predicate = predicate
        photoFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        photoFetchedResultsController.delegate = self
        do {
            try photoFetchedResultsController.performFetch()
        } catch {
            showOKAlert(error: CoreDataController.CoreDataError.badFetch)
        }
    }
    
    fileprivate func configPinFRC() {
        
        let fetchRequest:NSFetchRequest<Pin> = NSFetchRequest(entityName: "Pin")
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        let predicate = NSPredicate(format: "name = %@", pin.name!)
        fetchRequest.predicate = predicate
        pinFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        pinFetchedResultsController.delegate = self
        do {
            try pinFetchedResultsController.performFetch()
        } catch {
            showOKAlert(error: CoreDataController.CoreDataError.badFetch)
        }
    }
    
    @objc func handleEmptyPin() {
        showOKAlert(title: "Empty Album", message: "Press reload to download new Flick album.")
    }
    
    @objc func handleNoPhotosFound() {
        showOKAlert(title: "No Flicks Found", message: "Unable to locate flicks in this geographic region.")
    }
}
