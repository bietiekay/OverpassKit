import UIKit
import MapKit
import CoreLocation
import Combine
import OverpassKit

/// Example implementation of a ToiletFinder app using OverpassKit
/// This demonstrates how to use the library to find and display toilets on a map
class ToiletFinderExampleViewController: UIViewController {
    
    // MARK: - UI Elements
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: - Properties
    
    private let client = OverpassClient(endpoint: .miataru)
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    // Current search state
    private var currentBoundingBox: OverpassBoundingBox?
    private var isSearching = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMapView()
        setupLocationManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupMapType()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Toilet Finder"
        
        // Configure search button
        searchButton.setTitle("Find Toilets", for: .normal)
        searchButton.backgroundColor = .systemBlue
        searchButton.setTitleColor(.white, for: .normal)
        searchButton.layer.cornerRadius = 8
        searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        
        // Configure activity indicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .systemBlue
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        
        // Set initial region (San Francisco)
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(initialRegion, animated: false)
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50
        
        // Request location permissions
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func setupMapType() {
        // Check user preferences for map type
        let mapType = UserDefaults.standard.integer(forKey: "map_type")
        
        switch mapType {
        case 1:
            mapView.mapType = .standard
        case 2:
            mapView.mapType = .hybrid
        case 3:
            mapView.mapType = .satellite
        case 4:
            // Enable OSM tiles
            enableOSMTiles()
        default:
            mapView.mapType = .standard
        }
    }
    
    private func enableOSMTiles() {
        // Add OSM tile overlay
        let template = "http://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        overlay.maximumZ = 19
        
        mapView.addOverlay(overlay, level: .aboveLabels)
    }
    
    // MARK: - Actions
    
    @objc private func searchButtonTapped() {
        if isSearching {
            cancelSearch()
        } else {
            performSearch()
        }
    }
    
    private func performSearch() {
        guard let boundingBox = mapView.overpassBoundingBox() else {
            showAlert(title: "Error", message: "Unable to determine map bounds")
            return
        }
        
        currentBoundingBox = boundingBox
        isSearching = true
        updateUI()
        
        // Clear existing annotations
        clearAnnotations()
        
        // Show activity indicator
        activityIndicator.startAnimating()
        
        // Search for toilets
        client.findToilets(in: boundingBox)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.handleSearchCompletion(completion)
                },
                receiveValue: { [weak self] response in
                    self?.handleSearchResponse(response)
                }
            )
            .store(in: &cancellables)
    }
    
    private func cancelSearch() {
        client.cancelAllRequests()
        isSearching = false
        updateUI()
        activityIndicator.stopAnimating()
    }
    
    // MARK: - Search Handling
    
    private func handleSearchCompletion(_ completion: Subscribers.Completion<OverpassError>) {
        activityIndicator.stopAnimating()
        isSearching = false
        updateUI()
        
        switch completion {
        case .finished:
            print("Search completed successfully")
        case .failure(let error):
            handleSearchError(error)
        }
    }
    
    private func handleSearchResponse(_ response: OverpassResponse) {
        print("Found \(response.elements.count) toilets")
        
        // Add annotations to map
        addAnnotations(for: response.elements)
        
        // Show results summary
        showResultsSummary(response.elements.count)
    }
    
    private func handleSearchError(_ error: OverpassError) {
        var message = "An error occurred while searching"
        
        switch error {
        case .networkError(let networkError):
            message = "Network error: \(networkError.localizedDescription)"
        case .timeout:
            message = "Search timed out. Please try again."
        case .invalidResponse:
            message = "Invalid response from server"
        case .noData:
            message = "No toilets found in this area"
        case .queryError(let queryMessage):
            message = "Query error: \(queryMessage)"
        default:
            message = error.localizedDescription
        }
        
        showAlert(title: "Search Error", message: message)
    }
    
    // MARK: - Map Annotations
    
    private func addAnnotations(for elements: [OverpassElement]) {
        for element in elements {
            guard let coordinate = element.coordinate else { continue }
            
            let annotation = ToiletAnnotation(element: element)
            annotation.coordinate = coordinate
            annotation.title = element.name ?? "Toilet"
            annotation.subtitle = element.description ?? "Public toilet"
            
            mapView.addAnnotation(annotation)
        }
    }
    
    private func clearAnnotations() {
        let annotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(annotations)
    }
    
    // MARK: - UI Updates
    
    private func updateUI() {
        if isSearching {
            searchButton.setTitle("Cancel Search", for: .normal)
            searchButton.backgroundColor = .systemRed
        } else {
            searchButton.setTitle("Find Toilets", for: .normal)
            searchButton.backgroundColor = .systemBlue
        }
    }
    
    private func showResultsSummary(_ count: Int) {
        let message = count == 1 ? "Found 1 toilet" : "Found \(count) toilets"
        showAlert(title: "Search Results", message: message)
    }
    
    // MARK: - Utility Methods
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func centerOnUserLocation() {
        guard let userLocation = mapView.userLocation.location else { return }
        
        let region = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
    }
}

// MARK: - MKMapViewDelegate

extension ToiletFinderExampleViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Check if user is in center region
        if mapView.isUserInCenterRegion() {
            // User is centered, could auto-search here
            print("User is in center region")
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Don't customize user location annotation
        if annotation is MKUserLocation {
            return nil
        }
        
        // Customize toilet annotations
        if annotation is ToiletAnnotation {
            let identifier = "ToiletAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                // Add detail button
                let detailButton = UIButton(type: .detailDisclosure)
                annotationView?.rightCalloutAccessoryView = detailButton
            } else {
                annotationView?.annotation = annotation
            }
            
            // Customize pin appearance
            if let pinView = annotationView as? MKPinAnnotationView {
                pinView.pinTintColor = .systemBlue
                pinView.animatesDrop = true
            }
            
            return annotationView
        }
        
        return nil
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        // Handle detail button tap
        if let annotation = view.annotation as? ToiletAnnotation {
            showToiletDetails(annotation.element)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let tileOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: tileOverlay)
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

// MARK: - CLLocationManagerDelegate

extension ToiletFinderExampleViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            showAlert(title: "Location Access Required", message: "This app needs access to your location to find nearby toilets.")
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Center map on user location if this is the first update
        if mapView.userLocation.coordinate.latitude == 0 && mapView.userLocation.coordinate.longitude == 0 {
            centerOnUserLocation()
        }
        
        // Stop updating location after first update
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
        showAlert(title: "Location Error", message: "Unable to determine your location. Please check your location settings.")
    }
}

// MARK: - Toilet Annotation

/// Custom annotation class for toilet locations
class ToiletAnnotation: NSObject, MKAnnotation {
    let element: OverpassElement
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(element: OverpassElement) {
        self.element = element
        self.coordinate = element.coordinate ?? CLLocationCoordinate2D()
        self.title = element.name ?? "Toilet"
        self.subtitle = element.description ?? "Public toilet"
        super.init()
    }
}

// MARK: - Toilet Details View Controller

extension ToiletFinderExampleViewController {
    
    private func showToiletDetails(_ element: OverpassElement) {
        let detailVC = ToiletDetailViewController(element: element)
        let navController = UINavigationController(rootViewController: detailVC)
        present(navController, animated: true)
    }
}

/// View controller for displaying toilet details
class ToiletDetailViewController: UIViewController {
    
    private let element: OverpassElement
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let nameLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let coordinateLabel = UILabel()
    private let tagsLabel = UILabel()
    private let directionsButton = UIButton(type: .system)
    
    init(element: OverpassElement) {
        self.element = element
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureContent()
    }
    
    private func setupUI() {
        title = "Toilet Details"
        view.backgroundColor = .systemBackground
        
        // Add close button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        // Setup scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Setup labels
        setupLabel(nameLabel, title: "Name")
        setupLabel(descriptionLabel, title: "Description")
        setupLabel(coordinateLabel, title: "Coordinates")
        setupLabel(tagsLabel, title: "Tags")
        
        // Setup directions button
        directionsButton.setTitle("Get Directions", for: .normal)
        directionsButton.backgroundColor = .systemBlue
        directionsButton.setTitleColor(.white, for: .normal)
        directionsButton.layer.cornerRadius = 8
        directionsButton.addTarget(self, action: #selector(directionsButtonTapped), for: .touchUpInside)
        directionsButton.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(directionsButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            directionsButton.topAnchor.constraint(equalTo: tagsLabel.bottomAnchor, constant: 20),
            directionsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            directionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            directionsButton.heightAnchor.constraint(equalToConstant: 44),
            directionsButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupLabel(_ label: UILabel, title: String) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textColor = .label
        
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(label)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Layout constraints
        if contentView.subviews.count == 2 {
            // First label
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
                titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
                
                label.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
            ])
        } else {
            // Subsequent labels
            let previousLabel = contentView.subviews[contentView.subviews.count - 4] as! UILabel
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: previousLabel.bottomAnchor, constant: 20),
                titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
                
                label.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
            ])
        }
    }
    
    private func configureContent() {
        nameLabel.text = element.name ?? "Unnamed"
        descriptionLabel.text = element.description ?? "No description available"
        
        if let coordinate = element.coordinate {
            coordinateLabel.text = OverpassUtilities.formatCoordinate(coordinate)
        } else {
            coordinateLabel.text = "Coordinates not available"
        }
        
        // Format tags
        if let tags = element.tags {
            let tagStrings = tags.map { "\($0.key): \($0.value)" }
            tagsLabel.text = tagStrings.joined(separator: "\n")
        } else {
            tagsLabel.text = "No tags available"
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func directionsButtonTapped() {
        guard let coordinate = element.coordinate else { return }
        
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = element.name ?? "Toilet"
        
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
}
