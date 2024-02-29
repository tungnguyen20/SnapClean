//
//  HomeView.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    @EnvironmentObject var photoLoader: PhotosLoader
    
    var body: some View {
        VStack {
            HStack {
                Text("SnapClean")
                    .font(Font.system(size: 24, weight: .bold))
                Spacer()
                Image("setting")
            }
            
            ScrollView {
                ForEach(viewModel.sections) { section in
                    HomeSectionView(section: section) {
                        
                    }
                    .environmentObject(photoLoader)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Image("bg"))
    }
}

#Preview {
    HomeView(viewModel: .init())
}

struct HomeSectionView: View {
    @EnvironmentObject var photoLoader: PhotosLoader
    var section: HomeViewModel.Section
    @State var showDetail: Bool = false
    var onSelect: () -> ()
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.type.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("\(section.totalItems) items • \(section.totalSize / (1024 * 1024)) GB")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                NavigationLink(isActive: $showDetail) {
                    switch section.type {
                    case .screenshots:
                        ScreenshotAssetListView()
                            .navigationBarHidden(true)
                            .environmentObject(photoLoader)
                    default:
                        DefaultAssetListView()
                            .navigationBarHidden(true)
                            .environmentObject(photoLoader)
                    }
                } label: {
                    Button(action: {
                        showDetail = true
                    }, label: {
                        Text("Review")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.brand)
                            .padding(16)
                            .background(Color.gray100)
                            .clipShape(Capsule())
                    })
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
