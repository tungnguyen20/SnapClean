//
//  HomeSectionView.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import SwiftUI

struct HomeSectionView: View {
    var section: HomeViewModel.Section
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(section.type.title)
                        .font(.system(size: 18, weight: .bold))
                    Text("\(section.totalItems) items • \(section.totalSize / (1024 * 1024)) GB")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: {
                    
                }, label: {
                    Text("Review")
                        .font(.system(size: 18, weight: .bold))
                        .padding(16)
                        .background(Color.gray)
                })
            }
        }
    }
}
