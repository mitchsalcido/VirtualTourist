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
    
    enum UIState {
        case editing
        case downloading
        case normal
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        flowLayout.minimumLineSpacing = CellSpacing
        flowLayout.minimumInteritemSpacing = CellSpacing
        navigationItem.rightBarButtonItem = editButtonItem
        
        if flickrAnnotation.photosURLString.count != flickrAnnotation.downloadedFlicks.count {
            reloadAlbum()
        } else {
            collectionView.reloadData()
            updateUI(state: .normal)
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
            
            self.reloadAlbum()
        }
        alert.addAction(proceedAction)
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
        if image == defaultImage {
            cell.activityIndicator.startAnimating()
        } else {
            cell.activityIndicator.stopAnimating()
        }
        
        cell.imageView.alpha = isEditing ? 0.75 : 1.0
        cell.checkmarkImageView.isHidden = flicksToDelete.contains(indexPath) ? false : true

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

    fileprivate func reloadAlbum() {
        
        updateUI(state: .downloading)
        flickrAnnotation.downloadedFlicks = []
        flickrAnnotation.photosURLString = []
        collectionView.reloadData()
        activityIndicator.startAnimating()
        
        FlickrAPI.geoSearchFlickr(latitude: self.flickrAnnotation.coordinate.latitude, longitude: flickrAnnotation.coordinate.longitude) { success, error in
            
            if success {
                
                self.activityIndicator.stopAnimating()
                self.flickrAnnotation.photosURLString = FlickrAPI.flickURLStringArray
                self.configureDataSource()
                self.collectionView.reloadData()
                
                self.progressView.isHidden = false
                self.progressView.progress = 0.0
                
                var downloadCount:Float = 0.0
                let lastFlicksIndex = Float(self.flickrAnnotation.photosURLString.count - 1)
                
                self.downloadFlicks { index, image in
                    
                    self.flickrAnnotation.downloadedFlicks[index] = image
                    let indexPath = IndexPath(row: index, section: 0)
                    self.collectionView.reloadItems(at: [indexPath])
                    
                    if downloadCount == lastFlicksIndex {
                        self.progressView.isHidden = true
                        self.updateUI(state: .normal)
                    } else {
                        downloadCount += 1.0
                        self.progressView.progress = downloadCount / lastFlicksIndex
                    }
                }
            }
        }
    }
    
    fileprivate func downloadFlicks(completion: @escaping (Int, UIImage) -> Void) {
        
        for (index, urlString) in flickrAnnotation.photosURLString.enumerated() {
            if let url = URL(string: urlString) {
                FlickrAPI.getFlick(url: url) { image, error in
                    if let image = image {
                        completion(index, image)
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
