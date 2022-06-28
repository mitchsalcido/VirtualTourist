//
//  AlbumCollectionViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

import UIKit

private let reuseIdentifier = "AlbumCellID"

class AlbumCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
        
    var emptyBbi: UIBarButtonItem!
    
    var urlStrings:[String] = []
    var flicks:[UIImage] = []
    
    let CellSpacing:CGFloat = 5.0
    let CellsPerRow:CGFloat = 5.0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        flowLayout.minimumLineSpacing = CellSpacing
        flowLayout.minimumInteritemSpacing = CellSpacing
        
        if urlStrings.count > 0 {
            navigationItem.rightBarButtonItem = editButtonItem
        }

        downloadFlicks()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        flowLayout.invalidateLayout()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.reloadData()
        
        if editing {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashBbiPressed(sender:)))
            navigationItem.leftBarButtonItem?.isEnabled = false
        } else {
            navigationItem.leftBarButtonItem = nil
        }
    }
}

// MARK: UICollectionViewDataSource
extension AlbumCollectionViewController {
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return flicks.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! AlbumCollectionViewCell
    
        // Configure the cell
        cell.imageView.image = flicks[indexPath.row]
        
        if isEditing {
            cell.imageView.alpha = 0.75
        } else {
            cell.imageView.alpha = 1.0
        }
        
        return cell
    }
}

// MARK: UICollectionViewDelegate
extension AlbumCollectionViewController {

    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        
        if let cell = collectionView.cellForItem(at: indexPath) {
            if cell.isSelected {
                print("should: isSelected true")
                collectionView.deselectItem(at: indexPath, animated: false)
                return false
            } else {
                print("should: isSelected false")
                return true
            }
        }
        return true
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if let cell = collectionView.cellForItem(at: indexPath) {
            if cell.isSelected {
                print("did: isSelected true")
            } else {
                print("did: isSelected false")
            }
        }
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension AlbumCollectionViewController {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let size = collectionView.bounds.width - (CellsPerRow - 1.0) * CellSpacing
        return CGSize(width: size / CellsPerRow, height: size / CellsPerRow)
    }
}

// MARK: Helpers
extension AlbumCollectionViewController {
    
    fileprivate func downloadFlicks() {
        for urlString in urlStrings {
            if let url = URL(string: urlString) {
                
                FlickrAPI.getFlick(url: url) { image, error in
                    if let image = image {
                        // good image. Add to collectionView
                        let indexPath = IndexPath(row: self.flicks.count, section:0)
                        self.flicks.append(image)
                        self.collectionView.insertItems(at: [indexPath])
                    }
                }
            }
        }
    }
}

// MARK: BarButtonItem Actions
extension AlbumCollectionViewController {
    
    @objc func trashBbiPressed(sender: UIBarButtonItem) {
        print("trashBbiPresed")
    }
}
