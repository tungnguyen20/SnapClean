//
//  AssetSection.swift
//  SnapClean
//
//  Created by Tung Nguyen on 29/02/2024.
//

import SwiftUI
import Photos

struct AssetSection {
    var title: String
    var assets: [PHAsset]
    var style: AssetSectionStyle
}

enum AssetSectionStyle {
    case focusGrid
    case normalGrid
    case horizontalSquare
    case horizontalRect
}
