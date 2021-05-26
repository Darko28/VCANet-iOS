//
//  ContentView.swift
//  VCANet-iOS
//
//  Created by Chuanlong Li on 2021/5/25.
//

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var contentData: ContentData
    
    private let buttonText1 = ["Predict", "Reset"]
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack {
                    Color.clear.overlay(
                        Image(uiImage: self.contentData.detailImage!)
                            .resizable()
                            .scaledToFit()
                            .clipped()
                            .gesture(self.panGesture())
                    )
                    
                    HStack {
                        ForEach(buttonText1, id: \.self) { text in
                            Button(action: {
                                switch text {
                                case "Predict":
                                    self.contentData.analyze()
                                case "Reset":
                                    self.contentData.resetImage()
                                default:
                                    break
                                }
                            }, label: {
                                Text(text)
                                    .font(.title).bold()
                                    .padding()
                            })
                        }
                    }
                }
            }
        }
    }
        
    private func panGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                if value.translation.width < 0 {
                    self.contentData.nextImage()
                } else if value.translation.width > 0 {
                    self.contentData.previousImage()
                }
            }
    }
        
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(contentData: ContentData())
    }
}
