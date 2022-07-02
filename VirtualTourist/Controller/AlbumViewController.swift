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

class AlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
            
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var reloadBbi: UIBarButtonItem!
    
    var dataController:CoreDataController!
    var flicks:[Flick] = []
    
    var flickrAnnotation:FlickrAnnotation!
    var flicksToDeleteIndexPaths:Set<IndexPath> = []
    let defaultImage:UIImage = UIImage(imageLiteralResourceName: "DefaultImage")
    
    let CellsPerRow:CGFloat = 5.0
    let CellSpacing:CGFloat = 5.0
    
    enum UIState {
        case editing
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
        updateUI(state: .normal)
        loadFlicks()
    }
    
    fileprivate func loadFlicks() {
        guard let album = flickrAnnotation.album else {
            return
        }
        
        let fetchRequest:NSFetchRequest<Flick> = NSFetchRequest(entityName: "Flick")
        let sortDescriptor = NSSortDescriptor(key: "urlString", ascending: false)
        let predicate = NSPredicate(format: "album = %@", album)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.predicate = predicate
        do {
            flicks = try dataController.viewContext.fetch(fetchRequest)
            collectionView.reloadData()
        } catch {
            print("bad try")
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        flowLayout.invalidateLayout()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        flicksToDeleteIndexPaths.removeAll()
        collectionView.reloadData()
        
        if editing {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashBbiPressed(sender:)))
            navigationItem.leftBarButtonItem?.isEnabled = false
            updateUI(state: .editing)
        } else {
            updateUI(state: .normal)
        }
    }
    
    @IBAction func reloadBbiPressed(_ sender: Any) {
    
        let alert = UIAlertController(title: "Load New Album ?", message: "Existing phots will be deleted.", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let proceedAction = UIAlertAction(title: "Proceed", style: .destructive) { action in
            
        }
        alert.addAction(proceedAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
}

// MARK: UICollectionViewDataSource
extension AlbumViewController {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return flicks.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! AlbumCollectionViewCell
    
        let flick = flicks[indexPath.row]
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
    
        performSegue(withIdentifier: "FlickDetailSegueID", sender:flicks[indexPath.row])
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
        case .downloading:
            editButtonItem.isEnabled = false
            reloadBbi.isEnabled = false
        case .normal:
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
            editButtonItem.isEnabled = true
            reloadBbi.isEnabled = true
        }
    }
}

// MARK: BarButtonItem Actions
extension AlbumViewController {
    
    @objc func trashBbiPressed(sender: UIBarButtonItem) {
        
        var flicksToDelete:[Flick] = []
        for indexPath in flicksToDeleteIndexPaths {
            flicksToDelete.append(flicks[indexPath.row])
        }
        dataController.deleteManagedObjects(objects: flicksToDelete) { error in
            if error == nil {
                
                let updates = {
                    var indexPaths = self.flicksToDeleteIndexPaths.sorted()
                    indexPaths = indexPaths.reversed()
                    for indexPath in indexPaths {
                        self.flicks.remove(at: indexPath.row)
                    }
                    
                    self.collectionView.reloadSections(IndexSet(integer: 0))
                    self.setEditing(false, animated: false)
                }
                
                self.collectionView.performBatchUpdates(updates) { _ in
                }
            } else {
                print("non-nil error deleting flicks")
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
