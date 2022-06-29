//
//  AlbumCollectionViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

import UIKit
import CoreLocation

private let reuseIdentifier = "AlbumCellID"

class AlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
            
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var reloadBbi: UIBarButtonItem!
    
    var flickrAnnotation:FlickrAnnotation!

    var flicksToDelete:Set<IndexPath> = []
    
    var dataSource:[[String:UIImage]] = [[:]]
    let defaultImage:UIImage = UIImage(imageLiteralResourceName: "DefaultImage")
    
    let CellsPerRow:CGFloat = 5.0
    let CellSpacing:CGFloat = 5.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        flowLayout.minimumLineSpacing = CellSpacing
        flowLayout.minimumInteritemSpacing = CellSpacing
        
        navigationItem.rightBarButtonItem = editButtonItem
        
        if flickrAnnotation.photosURLString.count != flickrAnnotation.downloadedFlicks.count {
            configureDataSource()
            collectionView.reloadData()
            downloadFlicks()
            reloadBbi.isEnabled = false
        } else {
            collectionView.reloadData()
            progressView.isHidden = true
            reloadBbi.isEnabled = true
        }
        
        let coord = CLLocation(latitude: flickrAnnotation.coordinate.latitude, longitude: flickrAnnotation.coordinate.longitude)
        FlickrAPI.reverseGeoCode(location: coord) { string, error in
            self.title = string
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        flowLayout.invalidateLayout()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        flicksToDelete.removeAll()
        collectionView.reloadData()
        reloadBbi.isEnabled = !editing
        
        if editing {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashBbiPressed(sender:)))
            navigationItem.leftBarButtonItem?.isEnabled = false
        } else {
            navigationItem.leftBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
        }
    }
    
    @IBAction func reloadBbiPressed(_ sender: Any) {
    
        let alert = UIAlertController(title: "Reload New Album ?", message: "Existing phots will be deleted.", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let proceesAction = UIAlertAction(title: "Proceed", style: .destructive) { action in
            
            self.editButtonItem.isEnabled = false
            self.reloadBbi.isEnabled = false
            
            self.flickrAnnotation.downloadedFlicks = []
            self.flickrAnnotation.photosURLString = []
            self.collectionView.reloadData()
            self.activityIndicator.startAnimating()

            FlickrAPI.geoSearchFlickr(latitude: self.flickrAnnotation.coordinate.latitude, longitude: self.flickrAnnotation.coordinate.longitude) { success, error in
                
                if success {
                    self.activityIndicator.stopAnimating()
                    self.flickrAnnotation.photosURLString = FlickrAPI.flickURLStringArray
                    self.configureDataSource()
                    self.collectionView.reloadData()
                    self.downloadFlicks()
                    self.editButtonItem.isEnabled = true
                }
            }
        }
        alert.addAction(proceesAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
}

// MARK: UICollectionViewDataSource
extension AlbumViewController {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return flickrAnnotation.photosURLString.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! AlbumCollectionViewCell
    
        let image = flickrAnnotation.downloadedFlicks[indexPath.row]
        cell.imageView.image = image
        if image != defaultImage {
            cell.activityIndicator.stopAnimating()
        } else {
            cell.activityIndicator.startAnimating()
        }
        
        if isEditing {
            cell.imageView.alpha = 0.75
            
            if flicksToDelete.contains(indexPath) {
                cell.checkmarkImageView.isHidden = false
            } else {
                cell.checkmarkImageView.isHidden = true
            }
        } else {
            cell.imageView.alpha = 1.0
            cell.checkmarkImageView.isHidden = true
        }
        
        return cell
    }
}

// MARK: UICollectionViewDelegate
extension AlbumViewController {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if !self.isEditing {
            return
        }
        
        if flicksToDelete.contains(indexPath) {
            flicksToDelete.remove(indexPath)
        } else {
            flicksToDelete.insert(indexPath)
        }
        
        navigationItem.leftBarButtonItem?.isEnabled = !flicksToDelete.isEmpty
        
        collectionView.reloadItems(at: [indexPath])
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
    
    fileprivate func downloadFlicks() {
        
        let total = Float(flickrAnnotation.photosURLString.count)
        guard total > 0.0 else {
            return
        }
        
        var downloadCount:Float = 0.0
        reloadBbi.isEnabled = false
        progressView.isHidden = false
        progressView.progress = 0.0
        
        for (index, urlString) in flickrAnnotation.photosURLString.enumerated() {
            
            if let url = URL(string: urlString) {
                
                let flickIndex = index
                FlickrAPI.getFlick(url: url) { image, error in
                    if let image = image {
                        self.flickrAnnotation.downloadedFlicks[flickIndex] = image
                        let indexPath = IndexPath(row: flickIndex, section: 0)
                        self.collectionView.reloadItems(at: [indexPath])
                        downloadCount += 1.0
                        if downloadCount == total {
                            self.progressView.isHidden = true
                            self.reloadBbi.isEnabled = true
                        } else {
                            self.progressView.progress = downloadCount / total
                        }
                    }
                }
            }
        }
    }
    
    func configureDataSource() {
    
        flickrAnnotation.downloadedFlicks.removeAll()
        for _ in flickrAnnotation.photosURLString {
            flickrAnnotation.downloadedFlicks.append(defaultImage)
        }
    }
}

// MARK: BarButtonItem Actions
extension AlbumViewController {
    
    @objc func trashBbiPressed(sender: UIBarButtonItem) {
        
        let updates = {
            var indexPaths = self.flicksToDelete.sorted()
            indexPaths = indexPaths.reversed()
            for indexPath in indexPaths {
                self.flickrAnnotation.photosURLString.remove(at: indexPath.row)
                self.flickrAnnotation.downloadedFlicks.remove(at: indexPath.row)
            }
            
            self.collectionView.reloadSections(IndexSet(integer: 0))
            self.setEditing(false, animated: false)
        }
        
        collectionView.performBatchUpdates(updates) { _ in
        }
    }
}

