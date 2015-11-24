//
//  RendererImageProvider.swift
//  AsyncImageView
//
//  Created by Nacho Soto on 11/22/15.
//  Copyright © 2015 Nacho Soto. All rights reserved.
//

import Foundation
import ReactiveCocoa

// The initial value is `nil`.
private typealias ImageProperty = AnyProperty<RenderResult?>

/// ImageProviderType which guarantees that images for a given RenderDataType
/// are only rendered once, and multicasted to every observer.
public final class RendererImageProvider<
	RenderData: RenderDataType,
	Renderer: RendererType
	where
	Renderer.RenderData == RenderData,
	Renderer.Error == NoError
>: ImageProviderType {
	private let cache: InMemoryCache<RenderData, ImageProperty>

	private let renderer: Renderer

	public init(name: String, renderer: Renderer) {
		self.cache = InMemoryCache(cacheName: name)
		self.renderer = renderer
	}

	public func getImageForData(data: RenderData) -> SignalProducer<RenderResult, NoError> {
		return getImageForData(data, scheduler: QueueScheduler())
	}

	internal func getImageForData(data: RenderData, scheduler: SchedulerType) -> SignalProducer<RenderResult, NoError> {
		let property = getPropertyForData(data, scheduler: scheduler)

		let image = property.producer
			.filter { $0 != nil } // Skip initial `nil` value.
			.map { $0! }

		return image
			.take(1)
			.startOn(scheduler)
	}

	private func getPropertyForData(data: RenderData, scheduler: SchedulerType) -> ImageProperty {
		if let operation = cachedOperation(data) {
			return operation
		}

		let property = ImageProperty(
			initialValue: nil,
			producer: renderer.createProducerForRenderingData(data)
				.startOn(scheduler)
				.map(Optional.init)
		)
		cacheProperty(property, forData: data)

		return property
	}

	private func cachedOperation(data: RenderData) -> ImageProperty? {
		return cache.valueForKey(data)
	}

	private func cacheProperty(property: ImageProperty, forData data: RenderData) {
		cache.setValue(property, forKey: data)
	}
}

extension RendererType {
	private func createProducerForRenderingData(data: RenderData) -> SignalProducer<RenderResult, Error> {
		return self.renderImageWithData(data)
			.flatMap(.Concat) { image in
				return SignalProducer(values: [
					RenderResult(image: image, cacheHit: false),
					RenderResult(image: image, cacheHit: true)
				])
			}
	}
}
