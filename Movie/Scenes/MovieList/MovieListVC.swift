//
//  MovieListVC.swift
//  Movie
//
//  Created by Nevin Özkan on 24.10.2024.
//

import UIKit
import MovieAPI
import SDWebImage

class MovieListVC: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sliderCollectionView: UICollectionView!
    @IBOutlet weak var activity: UIActivityIndicatorView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    private var upcomingMovies: [MoviePresentation] = []
    private var nowPlayingMovies: [MoviePresentation] = []
    let service: MoviesServiceProtocol = MoviesService()
    var viewModel: MovieListViewModelProtocol!
    private let refreshControl = UIRefreshControl()
    private var isLoadingData = false
    var currentPage = 1
    private var totalPages: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        
        viewModel = MovieListViewModel(service: service)
        viewModel.delegate = self
        
        setupUI()
        setupSliderCollectionViewLayout()
        sliderCollectionView.delegate = self
        sliderCollectionView.dataSource = self
        registerCells()
        setupRefreshControl()
        
        viewModel.loadNowPlayingMovies()
        viewModel.loadUpcomingMovies(page: 1)
        
    }
    
    private func registerCells() {
        let nib = UINib(nibName: "MovieListCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "MovieListCell")
        
        let collectionNib = UINib(nibName: "MovieListCollectionCell", bundle: nil)
        sliderCollectionView.register(collectionNib, forCellWithReuseIdentifier: "MovieListCollectionCell")
    }
    
    private func setupSliderCollectionViewLayout() {
        if let layout = sliderCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 0
            sliderCollectionView.isPagingEnabled = true 
        }
    }
    
    private func setupUI() {
        view.addSubview(tableView)
        view.addSubview(sliderCollectionView)
        view.addSubview(pageControl)
        tableView.dataSource = self
        tableView.delegate = self
        
        pageControl.numberOfPages = nowPlayingMovies.count
        pageControl.currentPage = 0
        
        viewModel.loadUpcomingMovies(page: 0)
        viewModel.loadNowPlayingMovies()
        
        pageControl.numberOfPages = nowPlayingMovies.count
        pageControl.currentPage = 0
    }
    
    private func setupRefreshControl() {
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
    }
    
    @objc private func refreshData() {
        // Yenileme için mevcut sayfayı sıfırlayın
        
        currentPage = 1
        isLoadingData = true
        activity.startAnimating() // Yenileme başladığında aktivite göstergesini başlat
        
        // Mevcut verileri temizleyerek yeni sonuçları alın
        self.upcomingMovies = []
        self.nowPlayingMovies = []
        
        // Şu anda gösterilen ve yaklaşan filmleri yükleyin
        viewModel.loadNowPlayingMovies()
        viewModel.loadUpcomingMovies(page: currentPage)
        
        // Aşağıda, veri yüklenmesi tamamlandığında aktivite göstergesini durdurmak için
        DispatchQueue.global().async {
            // Ağ isteği gecikmesini simüle et
            sleep(2) // Ağ gecikmesini simüle edin (bunu üretimde kaldırın)
            
            DispatchQueue.main.async {
                self.activity.stopAnimating() // Veri yüklemesi tamamlandığında aktivite göstergesini durdur
                self.refreshControl.endRefreshing() // Yenilemeyi sonlandır
            }
        }
        
        print("Veriler yenileniyor: Sayfa \(currentPage)")
    }
}

extension MovieListVC: MovieListViewModelDelegate {
    func navigate(to route: MovieListViewRoute) {
        switch route {
        case .detail(let viewModel):
            let detailVC = MovieDetailVC(nibName: "MovieDetailVC", bundle: Bundle.main)
            detailVC.viewModel = viewModel
            self.navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    
    func handleViewModelOutput(_ output: MovieListViewModelOutput) {
        switch output {
        case .updateTitle(let title):
            self.title = title
        case .setLoading(let isLoading):
            isLoading ? activity.startAnimating() : activity.stopAnimating()
            isLoadingData = isLoading
            
        case .showMovieList(let newMovies, let totalPages):
            self.totalPages = totalPages
            if currentPage == 1 {
                self.upcomingMovies = newMovies
            } else {
                guard !newMovies.isEmpty else {
                    isLoadingData = false
                    return
                }
                self.upcomingMovies.append(contentsOf: newMovies)
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.sliderCollectionView.reloadData()
                self.currentPage += 1
                self.isLoadingData = false
                self.refreshControl.endRefreshing()
            }
        
        case .showNowPlayingMovieList(let nowPlayingMovies):
            self.nowPlayingMovies = nowPlayingMovies
            DispatchQueue.main.async {
                self.sliderCollectionView.reloadData()
                self.pageControl.numberOfPages = self.nowPlayingMovies.count
                self.pageControl.currentPage = 0
            }
        }
    }
}
    extension MovieListVC: UITableViewDataSource, UITableViewDelegate {
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return upcomingMovies.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MovieListCell", for: indexPath) as! MovieListCell
            let movie = upcomingMovies[indexPath.row]
            cell.prepareCell(with: movie)
            return cell
        }
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return 140
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let height = scrollView.frame.size.height
            
            if scrollView == tableView {
                if offsetY > contentHeight - height - 100 {
                    if !isLoadingData && currentPage < totalPages {
                        isLoadingData = true
                        currentPage += 1
                        viewModel.loadUpcomingMovies(page: currentPage)
                    }
                }
            }
        }

        
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            viewModel.selectMovie(at: indexPath.row)
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }

    extension MovieListVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return nowPlayingMovies.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MovieListCollectionCell", for: indexPath) as? MovieListCollectionCell else {
                fatalError("Hata: MovieListCollectionCell")
            }
            let movie = nowPlayingMovies[indexPath.item]
            cell.prepareCell(with: movie)
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
            return 0
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let pageIndex = Int(scrollView.contentOffset.x / scrollView.frame.size.width)
            pageControl.currentPage = pageIndex
        }
    }
