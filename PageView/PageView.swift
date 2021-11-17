//
//  PageView.swift
//  PageView
//
//  Created by szq on 2021/11/13.
//

import UIKit


class PageContainerView: UIView {
    
    var removeSubviewOnHidden = false
    override var isHidden: Bool {
        get { super.isHidden }
        set {
            super.isHidden = newValue
            if removeSubviewOnHidden && newValue {
                subviews.first?.removeFromSuperview()
            }
        }
    }
    
    var isContentSet: Bool {
        return subviews.count > 0
    }
    var contentView: UIView? {
        return subviews.first
    }
    override func addSubview(_ view: UIView) {
        if isContentSet {
            subviews.first?.removeFromSuperview()
        }
        // fill the entire container view
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.frame = .init(x: 0, y: 0, width: bounds.width, height: bounds.height)
        super.addSubview(view)
    }
}

public class PageView: UIScrollView {
    
    enum PageContainerType {
        case prev
        case main
        case next
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        
        isPagingEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bounces = true
        delegate = self
        
        for page in [mainPage, prevPage, nextPage] {
            page.isHidden = true
            page.translatesAutoresizingMaskIntoConstraints = false
            addSubview(page)
        }
        
        NSLayoutConstraint.activate([
            // content height = frame height
            contentLayoutGuide.heightAnchor.constraint(equalTo: self.heightAnchor),
            // pages all have same top as content
            mainPage.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            prevPage.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            nextPage.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            // pages all have the same size as scroll view frame
            mainPage.widthAnchor.constraint(equalTo: self.widthAnchor),
            mainPage.heightAnchor.constraint(equalTo: self.heightAnchor),
            prevPage.widthAnchor.constraint(equalTo: self.widthAnchor),
            prevPage.heightAnchor.constraint(equalTo: self.heightAnchor),
            nextPage.widthAnchor.constraint(equalTo: self.widthAnchor),
            nextPage.heightAnchor.constraint(equalTo: self.heightAnchor),
        ])
    }
    
    private var mainPage = PageContainerView()
    private var prevPage = PageContainerView()
    private var nextPage = PageContainerView()
    private var pageConstraints: [NSLayoutConstraint] = []
    
    private var pageContainerType: PageContainerType = .prev
    private var _pageIndex = 0
    
    private func setContentOffsetByContainerType() {
        switch (pageContainerType) {
        case .prev:
            contentOffset = .zero
        case .main, .next:
            contentOffset = .init(x: bounds.width, y: 0)
        }
    }
    
    private func setup(pageContent: UIView, to container: PageContainerView, forceSet: Bool=false) {
        guard forceSet || !container.isContentSet || (container.isContentSet && container.contentView! !== pageContent) else { return }
        
        container.addSubview(pageContent)
    }
    
    private func pageIndexDidSet() {
        guard let dataSource = dataSource,
              (0..<dataSource.numberOfPages(in: self)).contains(pageIndex) else { return }
        
        let numPages = dataSource.numberOfPages(in: self)
        guard numPages > 0 else { return }
        
        if pageIndex == 0 {
            prevPage.isHidden = false
            setup(pageContent: dataSource.pageView(self, pageAtIndex: pageIndex)!, to: prevPage)
            nextPage.isHidden = true
            
            if numPages > 1 {
                mainPage.isHidden = false
                setup(pageContent: dataSource.pageView(self, pageAtIndex: 1)!, to: mainPage)
            } else {
                mainPage.isHidden = true
            }
            
            pageContainerType = .prev
        } else if pageIndex == 1 {
            prevPage.isHidden = false
            setup(pageContent: dataSource.pageView(self, pageAtIndex: 0)!, to: prevPage)
            mainPage.isHidden = false
            setup(pageContent: dataSource.pageView(self, pageAtIndex: 1)!, to: mainPage)
            if numPages > 3 {
                nextPage.isHidden = false
                setup(pageContent: dataSource.pageView(self, pageAtIndex: 2)!, to: nextPage)
            } else {
                nextPage.isHidden = true
            }
            
            pageContainerType = .main
        } else if pageIndex == numPages - 1 {
            prevPage.isHidden = true
            mainPage.isHidden = false
            setup(pageContent: dataSource.pageView(self, pageAtIndex: pageIndex - 1)!, to: mainPage)
            nextPage.isHidden = false
            setup(pageContent: dataSource.pageView(self, pageAtIndex: pageIndex)!, to: nextPage)
            
            pageContainerType = .next
        } else {
            prevPage.isHidden = false
            setup(pageContent: dataSource.pageView(self, pageAtIndex: pageIndex - 1)!, to: prevPage)
            mainPage.isHidden = false
            setup(pageContent: dataSource.pageView(self, pageAtIndex: pageIndex)!, to: mainPage)
            nextPage.isHidden = false
            setup(pageContent: dataSource.pageView(self, pageAtIndex: pageIndex + 1)!, to: nextPage)
            
            pageContainerType = .main
        }
        
        setContentOffsetByContainerType()
        setNeedsUpdateConstraints()
        pageDelegate?.pageView(self, didTransitionTo: pageIndex)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        if !isTracking && !isDecelerating {
            // set the correct contentOffset according to pageContainerType
            setContentOffsetByContainerType()
        }
    }
    
    public override func updateConstraints() {
        if let numPages = dataSource?.numberOfPages(in: self), numPages > 0 {
            
            NSLayoutConstraint.deactivate(pageConstraints)
            if pageIndex == 0 && numPages == 1 {
                // mainPage & nextPage should be hidden
                pageConstraints = [
                    contentLayoutGuide.leadingAnchor.constraint(equalTo: prevPage.leadingAnchor),
                    contentLayoutGuide.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: 1.0),
                ]
            } else if pageIndex == 0 || (pageIndex == 1 && numPages == 2) {
                // nextPage should be hidden
                pageConstraints = [
                    contentLayoutGuide.leadingAnchor.constraint(equalTo: prevPage.leadingAnchor),
                    prevPage.trailingAnchor.constraint(equalTo: mainPage.leadingAnchor),
                    contentLayoutGuide.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: 2.0),
                ]
            } else if pageIndex == numPages - 1 {
                // prevPage should be hidden
                pageConstraints = [
                    contentLayoutGuide.leadingAnchor.constraint(equalTo: mainPage.leadingAnchor),
                    mainPage.trailingAnchor.constraint(equalTo: nextPage.leadingAnchor),
                    contentLayoutGuide.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: 2.0)
                ]
            } else {
                // no page is hidden
                pageConstraints = [
                    contentLayoutGuide.leadingAnchor.constraint(equalTo: prevPage.leadingAnchor),
                    prevPage.trailingAnchor.constraint(equalTo: mainPage.leadingAnchor),
                    mainPage.trailingAnchor.constraint(equalTo: nextPage.leadingAnchor),
                    contentLayoutGuide.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: 3.0),
                ]
            }
            
            NSLayoutConstraint.activate(pageConstraints)
        }
        
        super.updateConstraints()
    }
    
    // MARK: - Public Interface
    @IBInspectable public weak var pageDelegate: PageViewPageDelegate?
    @IBInspectable public weak var dataSource: PageViewDataSource? {
        didSet {
            if !(0..<dataSource!.numberOfPages(in: self)).contains(pageIndex) {
                pageIndex = dataSource!.numberOfPages(in: self) - 1
            } else {
                pageIndexDidSet()
            }
        }
    }
    
    @IBInspectable
    /// Distant page content view will be removed from container if true. Default is false. "Distant" means content view is not the neighbor of current displayed page.
    public var removeContentViewWhenDistant: Bool {
        get { mainPage.removeSubviewOnHidden }
        set {
            for page in [prevPage, mainPage, nextPage] {
                page.removeSubviewOnHidden = newValue
            }
        }
    }
    @IBInspectable
    /// Initial is 0. Can be set before dataSource is set.
    public var pageIndex: Int {
        get { _pageIndex }
        set {
            if let dataSource = dataSource, (0..<dataSource.numberOfPages(in: self)).contains(pageIndex) == false {
                // make sure in the correct range
                return
            }
            _pageIndex = newValue
            pageIndexDidSet()
        }
    }
    
    /// Page content view will be reloaded if reference of page content view changed.
    @objc public func reloadData() {
        if let dataSource = dataSource, (0..<dataSource.numberOfPages(in: self)).contains(pageIndex) == false {
            // out of range
            pageIndex = dataSource.numberOfPages(in: self) - 1
            return
        }
        // refresh page content
        pageIndexDidSet()
    }
}

// MARK: - UIScrollViewDelegate
extension PageView: UIScrollViewDelegate {
    
    private var inferedContainerTypeFromOffset: PageContainerType {
        let EPS = 10.0 // there will be strange float round error without epsilon
        
        if contentSize.width < bounds.width + EPS {
            return .prev
        } else if contentSize.width < bounds.width * 2 + EPS {
            if contentOffset.x < EPS {
                return prevPage.isHidden ? .main : .prev
            } else {
                return nextPage.isHidden ? .main : .next
            }
        } else {
            if contentOffset.x < EPS {
                return .prev
            } else if contentOffset.x < bounds.width + EPS {
                return .main
            } else {
                return .next
            }
        }
    }
    
    /// correctly fetch and setup page content, toggle the isHidden property and maintain the sequence of page containers after user trying to switch pages
    private func pageDidChanged() {
        
        guard let dataSource = dataSource else { return }
        
        let numPages = dataSource.numberOfPages(in: self)
        guard numPages > 0 else { return }
        
        if inferedContainerTypeFromOffset == .prev {
            // scroll to prevPage
            guard pageIndex != 0 else { return }
            
            _pageIndex -= 1
            if pageIndex == 0 {
                // at the first page
                nextPage.isHidden = true
                
                pageContainerType = .prev
            } else {
                // at the previous page
                setup(pageContent: dataSource.pageView(self, pageAtIndex: pageIndex - 1)!, to: nextPage)
                (prevPage, mainPage, nextPage) = (nextPage, prevPage, mainPage)
                
                pageContainerType = .main
            }
        } else if inferedContainerTypeFromOffset == .next {
            // scroll to nextPage
            guard pageIndex != numPages - 1 else { return }
            
            _pageIndex += 1
            if pageIndex == numPages - 1 {
                // scroll to the final page
                prevPage.isHidden = true
                
                pageContainerType = .next
            } else {
                // next but not final
                setup(pageContent: dataSource.pageView(self, pageAtIndex: pageIndex + 1)!, to: prevPage)
                (prevPage, mainPage, nextPage) = (mainPage, nextPage, prevPage)
                
                pageContainerType = .main
            }
        } else {
            // still at the main page
            if pageIndex == 0 {
                // scroll to mainPage from pageIndex=0
                _pageIndex += 1
                if numPages > 2 {
                    nextPage.isHidden = false
                    if !nextPage.isContentSet {
                        setup(pageContent: dataSource.pageView(self, pageAtIndex: pageIndex + 1)!, to: nextPage)
                    }
                }
                
                pageContainerType = .main
            } else if pageIndex == numPages - 1 && numPages != 2 {
                // scroll to mainPage from the final page
                _pageIndex -= 1
                prevPage.isHidden = false
                if !prevPage.isContentSet {
                    setup(pageContent: dataSource.pageView(self, pageAtIndex: pageIndex - 1)!, to: prevPage)
                }
                
                pageContainerType = .next
            } else {
                return
            }
        }
        
        setContentOffsetByContainerType() // needed when bounces turned on, bounces will cause "if block" in overridded layoutSubviews() being skipped in fast swipping scenario
        setNeedsUpdateConstraints()
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate == false {
            pageDidChanged()
            pageDelegate?.pageView(self, didTransitionTo: pageIndex)
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageDidChanged()
        pageDelegate?.pageView(self, didTransitionTo: pageIndex)
    }
}

// MARK: - DataSource & PageDelegate Protocal
@objc public protocol PageViewDataSource: NSObjectProtocol {
    
    func numberOfPages(in pageView: PageView) -> Int
    
    func pageView(_ pageView: PageView, pageAtIndex idx: Int) -> UIView?
}


@objc public protocol PageViewPageDelegate: NSObjectProtocol {
    
    /// Called when page switched. PageIndex can be the same as the last one.
    func pageView(_ pageView: PageView, didTransitionTo pageIndex: Int)
}
