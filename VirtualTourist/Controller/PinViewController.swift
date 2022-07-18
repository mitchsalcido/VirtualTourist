//
//  PinViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//
/*
 About PinViewController:
 Present a collection view for displaying downloaded(also downloading) photos. Implements functionality for deleting photos, reloading a new set of photos, and navigating to a PhotoDetailViewController to view larger photo.
 */

import UIKit
import CoreLocation
import CoreData

private let reuseIdentifier = "AlbumCellID"

class PinViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, NSFetchedResultsControllerDelegate {
            
    // progress of downloading photos
    @IBOutlet weak var progressView: UIProgressView!
    
    // view photos in a collectionView
    @IBOutlet weak var collectionView: UICollectionView!
    
    // delegate for collectionViewCell layout
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    // indicate beginning of new photo set reload
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // Bar Button for invoking reloading a new set of photos
    @IBOutlet weak var reloadBbi: UIBarButtonItem!
    
    // ref to managed object Pin. Contains location, name, and photos
    var pin:Pin!
    
    // FRC for photos in collectionView. Manage insertion/deletion of photos
    var photoFetchedResultsController:NSFetchedResultsController<Photo>!
    
    // FRC for Pin. Handle UI when downloading new photo set
    var pinFetchedResultsController:NSFetchedResultsController<Pin>!
    
    // ref to core data stack
    var dataController:CoreDataController!
    
    /*
     In edit mode, tapped photos indexPaths are stored in this property. When trash in pressed, photos in this set are deleted.
     */
    var photosToDeleteIndexPaths:Set<IndexPath> = []
    
    
    // default image to display in cells when photos are being downloaded
    let defaultImage:UIImage = UIImage(imageLiteralResourceName: "DefaultImage")
    
    // for tracking download progress. Used by progress indicator
    var downloadedPhotoCount:Int = 0
    
    // collectionView cell spacing
    let CellsPerRow:CGFloat = 5.0
    let CellSpacing:CGFloat = 5.0
    
    // enum for state of controller
    enum UIState {
        case editing            // editing mode. User can select a photo for deletion
        case preDownloading     // about to download a new photo set
        case downloading        // downloading a new photo set
        case normal             // normal mode.
        case noPhotosFound      // indicates no photos in geographic region
        case emptyPin           // photo's available, but not downloaded
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // retrieve dataController
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        dataController = appDelegate.dataController
        
        // set cell spacing
        flowLayout.minimumLineSpacing = CellSpacing
        flowLayout.minimumInteritemSpacing = CellSpacing
        
        // edit and reload buttons
        navigationItem.rightBarButtonItem = editButtonItem
        editButtonItem.isEnabled = false
        reloadBbi.isEnabled = false
        title = pin.name
        
        // configure FetchedResultsControllers
        configPhotoFRC()
        configPinFRC()
        
        /*
         check download count. Update UI based on count
         */
        downloadedPhotoCount = pin.downloadedPhotoImageCount()
        let zeroCount = (downloadedPhotoCount == 0)
        
        if pin.noPhotosFound {
            // no photos in geographic region
            updateUI(state: .noPhotosFound)
            perform(#selector(handleNoPhotosFound), with: nil, afterDelay: 1.0)
        } else if !pin.noPhotosFound && pin.photoDownloadComplete && zeroCount {
            // photos available, but not downloaded
            updateUI(state: .emptyPin)
            perform(#selector(handleEmptyPin), with: nil, afterDelay: 1.0)
        } else if !pin.noPhotosFound && pin.photoDownloadComplete && !zeroCount {
            // good download with photos present
            updateUI(state: .normal)
        } else if !pin.noPhotosFound && !pin.photoDownloadComplete {
            // currently downloading
            updateUI(state: .downloading)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        // device rotation. Invalidate current layout
        flowLayout.invalidateLayout()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        /*
         remove all photos to delete when entering/exiting editing mode
         */
        photosToDeleteIndexPaths.removeAll()
        
        // UI
        if editing {
            updateUI(state: .editing)
        } else {
            updateUI(state: .normal)
        }
        
        // reload
        collectionView.reloadData()
    }
}

// MARK: UICollectionViewDataSource
extension PinViewController {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // count of photos regardless of download state
        return photoFetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PhotoCollectionViewCell
    
        /*
         retireve photo. If nil imageData then use defaultImage with activityIndicator in cell to show downloading in progress
         */
        let photo = photoFetchedResultsController.object(at: indexPath)
        if let imageData = photo.imageData {
            cell.imageView.image = UIImage(data: imageData)
            cell.activityIndicator.stopAnimating()
        } else {
            cell.imageView.image = defaultImage
            cell.activityIndicator.startAnimating()
        }
        
        // test for editing. Dim cell if editing
        cell.imageView.alpha = isEditing ? 0.75 : 1.0
        
        // test for photo/cell to be deleted. Show checkmark if to be deleted
        cell.checkmarkImageView.isHidden = !photosToDeleteIndexPaths.contains(indexPath)

        return cell
    }
}

// MARK: UICollectionViewDelegate
extension PinViewController {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        /*
         Handle cell selection for marking cell/photo to be deleted (checkmark)
         */
        if self.isEditing {
            /*
             If in editing mode, add/remove from photosToDeleteIndexPaths as cell is selected/deselected
             */
            if photosToDeleteIndexPaths.contains(indexPath) {
                photosToDeleteIndexPaths.remove(indexPath)
            } else {
                photosToDeleteIndexPaths.insert(indexPath)
            }
            
            // enable trash button only if photos are selected for deletion
            navigationItem.leftBarButtonItem?.isEnabled = !photosToDeleteIndexPaths.isEmpty
            collectionView.reloadItems(at: [indexPath])
            
            return
        }
        
        // not editing. Navigate to PhotoDetailViewController to view larger size image
        let photo = photoFetchedResultsController.object(at: indexPath)
        if photo.imageData != nil {
            performSegue(withIdentifier: "PhotoDetailSegueID", sender:photo)
        }
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension PinViewController {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        /*
         update cell spacing during device rotation
         */
        let size = collectionView.bounds.width - (CellsPerRow - 1.0) * CellSpacing
        return CGSize(width: size / CellsPerRow, height: size / CellsPerRow)
    }
}

// MARK: BarButtonItem Target/Actions
extension PinViewController {
    
    @objc func trashBbiPressed(sender: UIBarButtonItem) {
        /*
         handle photos deletion. Retrieve photos to delete into an array. Then delete array of photos
         */
        
        // place photos to delete into array
        var photosToDelete:[Photo] = []
        for indexPath in photosToDeleteIndexPaths {
            let photo = photoFetchedResultsController.object(at: indexPath)
            photosToDelete.append(photo)
        }
        
        // delete photos
        dataController.deleteManagedObjects(objects: photosToDelete) { error in
            if let error = error {
                self.showOKAlert(error: error)
            }
        }
    }
    
    @IBAction func reloadBbiPressed(_ sender: Any) {
        /*
         Handle reloading a new photo set. Present an alert with cancel and proceed action.
         */
        let alert = UIAlertController(title: "Load New Album ?", message: "Existing photos will be deleted.", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let proceedAction = UIAlertAction(title: "Proceed", style: .destructive) { action in
            
            /*
             Proceed action. Retrieve and delete existing photos.
             */
            if let photos = self.pin.photos?.allObjects as? [Photo] {
                
                self.dataController.deleteManagedObjects(objects: photos) { error in
                    if let error = error {
                        // bad deletion
                        self.showOKAlert(error: error)
                    } else {
                        /*
                         Good deletion. Proceed with reload after updating UI to reflect new download state.
                         */
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
        if segue.identifier == "PhotoDetailSegueID" {
            /*
             Navigate to PhotoDetailViewController to view larger photo
             */
            let controller = segue.destination as! PhotoDetailViewController
            controller.photo = sender as? Photo
        }
    }
}

// MARK: FetchedResultsController Delegate
extension PinViewController {

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
       /*
        didChange for fetchedResultsController
        */
        if controller == photoFetchedResultsController {
            /*
             Photo FRC didChange. Test for photostoDeleteIndexPath not empty, then perform batch update to remove cells with these indexPaths
             */
            if !photosToDeleteIndexPaths.isEmpty {
                // cells need to be deleted, batch delete
                collectionView.performBatchUpdates {
                    self.collectionView.deleteItems(at: Array(photosToDeleteIndexPaths))
                }
                setEditing(false, animated: false)
            }
        }
        
        if controller == pinFetchedResultsController {
            /*
             Pin FRC didChange. Test for empty fetchedObjects and updateUI. Triggered by Pin download completing.
             */
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
        /*
         Handle update. Occurs when Photo completed download of imageData and context is saved.
         */
        if controller == photoFetchedResultsController {
            if type == .update {
                // update occured. A Photo managed object imageData has been retrieved and saved during download process.
                if let indexPath = indexPath {
                    collectionView.reloadItems(at: [indexPath])
                    
                    // count downloads. Used by progressView to track Pin Photo set download progress.
                    downloadedPhotoCount += 1
                    let total = pin.photos?.count ?? 1
                    progressView.progress = Float(downloadedPhotoCount) / Float(total)
                    
                    // at first successful download, change UI state to downloading.
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
