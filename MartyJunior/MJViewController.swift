//
//  MJSlideViewController.swift
//  MartyJunior
//
//  Created by 鈴木大貴 on 2015/11/26.
//  Copyright © 2015年 Taiki Suzuki. All rights reserved.
//

import UIKit
import MisterFusion

public class MJViewController: UIViewController {
    private class RegisterCellContainer {
        struct NibAndIdentifierContainer {
            let nib: UINib?
            let reuseIdentifier: String
        }
        struct ClassAndIdentifierContainer {
            let aClass: AnyClass?
            let reuseIdentifier: String
        }
        var cellNib: [NibAndIdentifierContainer] = []
        var cellClass: [ClassAndIdentifierContainer] = []
        var headerFooterNib: [NibAndIdentifierContainer] = []
        var headerFooterClass: [ClassAndIdentifierContainer] = []
    }
    
    public weak var delegate: MJViewControllerDelegate?
    public weak var dataSource: MJViewControllerDataSource?

    private var onceToken: dispatch_once_t = 0
    
    private let scrollView: UIScrollView = UIScrollView()
    private let scrollContainerView: UIView = UIView()
    private var scrollContainerViewWidthConstraint: NSLayoutConstraint?
    
    private let contentView: MJContentView = MJContentView()
    private var contentViewTopConstraint: NSLayoutConstraint?
    private let contentEscapeView: UIView = UIView()
    
    private var containerViews: [UIView] = []
    private var viewControllers: [MJTableViewController] = []
    private let registerCellContainer: RegisterCellContainer = RegisterCellContainer()
    
    public var tableViews: [UITableView] {
        return viewControllers.map { $0.tableView }
    }
    
    public private(set) var titles: [String]?
    
    public var numberOfTabs: Int {
        return titles?.count ?? 0
    }
    
    public var selectedIndex: Int {
        get {
            return Int(scrollView.contentOffset.x / scrollView.bounds.size.width)
        }
        set {
            scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.bounds.size.width * CGFloat(newValue)), animated: false)
        }
    }
    
    public var selectedViewController: MJTableViewController {
        return viewControllers[selectedIndex]
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    public override func viewWillAppear(animated: Bool) {
        dispatch_once(&onceToken) {
            self.setupViews()
        }
    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

//MARK: - Private
extension MJViewController {
    private func setupViews() {
        guard let dataSource = dataSource else { return }
        titles = dataSource.mjViewControllerTitlesForTab(self)
        contentView.titles = titles
        contentView.segmentedControl.selectedSegmentIndex = 0
        contentView.userDefinedView = dataSource.mjViewControllerContentViewForTop(self)
        
        scrollView.pagingEnabled = true
        scrollView.delegate = self
        view.addLayoutSubview(scrollView, andConstraints:
            scrollView.Top,
            scrollView.Left,
            scrollView.Right,
            scrollView.Bottom
        )
        
        scrollContainerViewWidthConstraint = scrollView.addLayoutSubview(scrollContainerView, andConstraints:
            scrollContainerView.Top,
            scrollContainerView.Left,
            scrollContainerView.Right,
            scrollContainerView.Bottom,
            scrollContainerView.Height |==| scrollView.Height,
            scrollContainerView.Width |==| scrollView.Width |*| CGFloat(numberOfTabs)
        ).firstAttribute(.Width).first
        
        setupContainerViews()
        setupTableViewControllers()
        registerNibAndClassForTableViews()
        
        view.addLayoutSubview(contentEscapeView, andConstraints:
            contentEscapeView.Top,
            contentEscapeView.Left,
            contentEscapeView.Right,
            contentEscapeView.Height |=| contentView.height
        )
        
        view.layoutIfNeeded()
        
        contentEscapeView.backgroundColor = .clearColor()
        contentEscapeView.userInteractionEnabled = false
        contentEscapeView.hidden = true
    }
    
    private func setupContainerViews() {
        (0..<numberOfTabs).forEach {
            let containerView = UIView()
            let misterFusions: [MisterFusion]
            switch $0 {
            case 0:
                misterFusions = [
                    containerView.Left,
                ]
                
            case (numberOfTabs - 1):
                guard let previousContainerView = containerViews.last else { return }
                misterFusions = [
                    containerView.Right,
                    containerView.Left |==| previousContainerView.Right,
                ]
                
            default:
                guard let previousContainerView = containerViews.last else { return }
                misterFusions = [
                    containerView.Left |==| previousContainerView.Right,
                ]
            }
            
            let commomMisterFusions = [
                containerView.Top,
                containerView.Bottom,
                containerView.Width |/| CGFloat(numberOfTabs)
            ]
            scrollContainerView.addLayoutSubview(containerView, andConstraints: misterFusions + commomMisterFusions)
            containerViews += [containerView]
        }
        contentView.delegate = self
    }
    
    private func setupTableViewControllers() {
        containerViews.forEach {
            let viewController = MJTableViewController()
            viewController.delegate = self
            viewController.dataSource = self
            $0.addLayoutSubview(viewController.view, andConstraints:
                viewController.view.Top,
                viewController.view.Left,
                viewController.view.Right,
                viewController.view.Bottom
            )
            addChildViewController(viewController)
            viewController.didMoveToParentViewController(self)
            viewControllers += [viewController]
        }
    }
    
    private func addContentViewToCell() {
        contentEscapeView.hidden = true
        contentViewTopConstraint = nil
        
        let cells = selectedViewController.tableView.visibleCells.filter { $0.isKindOfClass(MJTableViewTopCell.self) }
        let cell = cells.first as? MJTableViewTopCell
        cell?.mainContentView = contentView
        contentView.segmentedControl.selectedSegmentIndex = selectedIndex
    }
    
    private func addContentViewToEscapeView() {
        contentEscapeView.hidden = false
        contentViewTopConstraint = contentEscapeView
            .addLayoutSubview(contentView, andConstraints:
                contentView.Top |-| selectedViewController.tableView.contentOffset.y,
                contentView.Left,
                contentView.Right,
                contentView.Height |=| contentView.height
            ).firstAttribute(.Top).first
    }
    
    private func indexOfViewController(viewController: MJTableViewController) -> Int {
        return viewControllers.indexOf(viewController) ?? 0
    }
    
    private func registerNibAndClassForTableViews() {
        tableViews.forEach { tableView in
            registerCellContainer.cellNib.forEach { tableView.registerNib($0.nib, forCellReuseIdentifier: $0.reuseIdentifier) }
            registerCellContainer.headerFooterNib.forEach { tableView.registerNib($0.nib, forHeaderFooterViewReuseIdentifier: $0.reuseIdentifier) }
            registerCellContainer.cellClass.forEach { tableView.registerClass($0.aClass, forCellReuseIdentifier: $0.reuseIdentifier) }
            registerCellContainer.headerFooterClass.forEach { tableView.registerClass($0.aClass, forHeaderFooterViewReuseIdentifier: $0.reuseIdentifier) }
        }
    }
}

//MARK: - Public
extension MJViewController {
    public func registerNibToAllTableViews(nib: UINib?, forCellReuseIdentifier reuseIdentifier: String) {
        registerCellContainer.cellNib += [RegisterCellContainer.NibAndIdentifierContainer(nib: nib, reuseIdentifier: reuseIdentifier)]
    }
    
    public func registerNibToAllTableViews(nib: UINib?, forHeaderFooterViewReuseIdentifier reuseIdentifier: String) {
        registerCellContainer.headerFooterNib += [RegisterCellContainer.NibAndIdentifierContainer(nib: nib, reuseIdentifier: reuseIdentifier)]
    }
    
    public func registerClassToAllTableViews(aClass: AnyClass?, forCellReuseIdentifier reuseIdentifier: String) {
        registerCellContainer.cellClass += [RegisterCellContainer.ClassAndIdentifierContainer(aClass: aClass, reuseIdentifier: reuseIdentifier)]
    }
    
    public func registerClassToAllTableViews(aClass: AnyClass?, forHeaderFooterViewReuseIdentifier reuseIdentifier: String) {
        registerCellContainer.headerFooterClass += [RegisterCellContainer.ClassAndIdentifierContainer(aClass: aClass, reuseIdentifier: reuseIdentifier)]
    }
}

//MARK: - UIScrollViewDelegate
extension MJViewController: UIScrollViewDelegate {
    public func scrollViewDidScroll(scrollView: UIScrollView) {

    }
    
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if contentView.superview == contentEscapeView && !decelerate {
            addContentViewToCell()
        }
    }
    
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        if contentView.superview == contentEscapeView {
            addContentViewToCell()
        }
    }
    
    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        if contentView.superview != contentEscapeView {
            addContentViewToEscapeView()
        }
    }
}

//MARK: - MJTableViewControllerDataSource
extension MJViewController: MJTableViewControllerDataSource {
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell? {
        return dataSource?.mjViewController(self, targetIndex: indexOfViewController(viewController), tableView: tableView, cellForRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, numberOfRowsInSection section: Int) -> Int? {
        return dataSource?.mjViewController(self, targetIndex: indexOfViewController(viewController), tableView: tableView, numberOfRowsInSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, numberOfSectionsInTableView tableView: UITableView) -> Int? {
        return dataSource?.mjViewController?(self, targetIndex: indexOfViewController(viewController), numberOfSectionsInTableView: tableView)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataSource?.mjViewController?(self, targetIndex: indexOfViewController(viewController), tableView: tableView, titleForHeaderInSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return dataSource?.mjViewController?(self, targetIndex: indexOfViewController(viewController), tableView: tableView, titleForFooterInSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool? {
        return dataSource?.mjViewController?(self, targetIndex: indexOfViewController(viewController), tableView: tableView, canEditRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool? {
        return dataSource?.mjViewController?(self, targetIndex: indexOfViewController(viewController), tableView: tableView, canMoveRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, sectionIndexTitlesForTableView tableView: UITableView) -> [String]? {
        return dataSource?.mjViewController?(self, targetIndex: indexOfViewController(viewController), sectionIndexTitlesForTableView: tableView)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int? {
        return dataSource?.mjViewController?(self, targetIndex: indexOfViewController(viewController), tableView: tableView, sectionForSectionIndexTitle: title, atIndex: index)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        dataSource?.mjViewController?(self, targetIndex: indexOfViewController(viewController), tableView: tableView, commitEditingStyle: editingStyle, forRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        dataSource?.mjViewController?(self, targetIndex: indexOfViewController(viewController), tableView: tableView, moveRowAtIndexPath: sourceIndexPath, toIndexPath: destinationIndexPath)
    }
}

//MARK: - MJTableViewControllerDelegate
extension MJViewController: MJTableViewControllerDelegate {
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, estimatedHeightForTopCellAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return contentView.height
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, heightForTopCellAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return contentView.height
    }
    
    func tableViewController(viewController: MJTableViewController, tableViewTopCell cell: MJTableViewTopCell) {
        if viewController != selectedViewController { return }
        cell.mainContentView = contentView
    }
    
    func tableViewController(viewController: MJTableViewController, scrollViewDidEndDecelerating scrollView: UIScrollView) {
        let viewControllers = self.viewControllers.filter { $0 != selectedViewController }
        viewControllers.forEach { $0.tableView.setContentOffset(scrollView.contentOffset, animated: false) }
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewDidEndDecelerating: scrollView)
    }
    
    func tableViewController(viewController: MJTableViewController, scrollViewDidScroll scrollView: UIScrollView) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewDidScroll: scrollView)
    }
    
    func tableViewController(viewController: MJTableViewController, scrollViewDidEndDragging scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let viewControllers = self.viewControllers.filter { $0 != selectedViewController }
        viewControllers.forEach { $0.tableView.setContentOffset(scrollView.contentOffset, animated: false) }
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewDidEndDragging: scrollView, willDecelerate: decelerate)
    }

    func tableViewController(viewController: MJTableViewController, scrollViewDidZoom scrollView: UIScrollView) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewDidZoom: scrollView)
    }
    
    func tableViewController(viewController: MJTableViewController, scrollViewWillBeginDragging scrollView: UIScrollView) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewWillBeginDragging: scrollView)
    }
    
    func tableViewController(viewController: MJTableViewController, scrollViewWillEndDragging scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewWillEndDragging: scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
    }
    
    func tableViewController(viewController: MJTableViewController,  scrollViewWillBeginDecelerating scrollView: UIScrollView) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewWillBeginDecelerating: scrollView)
    }

    func tableViewController(viewController: MJTableViewController, scrollViewDidEndScrollingAnimation scrollView: UIScrollView) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewDidEndScrollingAnimation: scrollView)
    }
    
    func tableViewController(viewController: MJTableViewController, viewForZoomingInScrollView scrollView: UIScrollView) -> UIView? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, viewForZoomingInScrollView: scrollView)
    }
    
    func tableViewController(viewController: MJTableViewController, scrollViewWillBeginZooming scrollView: UIScrollView, withView view: UIView?) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewWillBeginZooming: scrollView, withView: view)
    }
    
    func tableViewController(viewController: MJTableViewController, scrollViewDidEndZooming scrollView: UIScrollView, withView view: UIView?, atScale scale: CGFloat) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewDidEndZooming: scrollView, withView: view, atScale: scale)
    }
    
    func tableViewController(viewController: MJTableViewController, scrollViewShouldScrollToTop scrollView: UIScrollView) -> Bool? {
        if viewController != selectedViewController { return false }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewShouldScrollToTop: scrollView)
    }
    
    func tableViewController(viewController: MJTableViewController, scrollViewDidScrollToTop scrollView: UIScrollView) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, scrollViewDidScrollToTop: scrollView)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, willDisplayCell: cell, forRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, willDisplayHeaderView: view, forSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, willDisplayFooterView: view, forSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, didEndDisplayingCell: cell, forRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, didEndDisplayingHeaderView view: UIView, forSection section: Int) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, didEndDisplayingHeaderView: view, forSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, didEndDisplayingFooterView view: UIView, forSection section: Int) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, didEndDisplayingFooterView: view, forSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, heightForRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, heightForHeaderInSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, heightForFooterInSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, estimatedHeightForRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, estimatedHeightForHeaderInSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, estimatedHeightForFooterInSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, viewForHeaderInSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, viewForFooterInSection: section)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, accessoryButtonTappedForRowWithIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, shouldHighlightRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, didHighlightRowAtIndexPath indexPath: NSIndexPath) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, didHighlightRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, didUnhighlightRowAtIndexPath indexPath: NSIndexPath) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, didUnhighlightRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, willSelectRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, willDeselectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, willDeselectRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, didSelectRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, didDeselectRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, editingStyleForRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String? {
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, titleForDeleteConfirmationButtonForRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, editActionsForRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, shouldIndentWhileEditingRowAtIndexPath indexPath: NSIndexPath) -> Bool? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, shouldIndentWhileEditingRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, willBeginEditingRowAtIndexPath indexPath: NSIndexPath) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, willBeginEditingRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, didEndEditingRowAtIndexPath indexPath: NSIndexPath) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, didEndEditingRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: NSIndexPath, toProposedIndexPath proposedDestinationIndexPath: NSIndexPath) -> NSIndexPath? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, targetIndexPathForMoveFromRowAtIndexPath: sourceIndexPath, toProposedIndexPath: proposedDestinationIndexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, indentationLevelForRowAtIndexPath indexPath: NSIndexPath) -> Int? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, indentationLevelForRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, shouldShowMenuForRowAtIndexPath indexPath: NSIndexPath) -> Bool? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, shouldShowMenuForRowAtIndexPath: indexPath)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, canPerformAction action: Selector, forRowAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) -> Bool? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, canPerformAction: action, forRowAtIndexPath: indexPath, withSender: sender)
    }
    
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, performAction action: Selector, forRowAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, performAction: action, forRowAtIndexPath: indexPath, withSender: sender)
    }
    
    @available(iOS 9.0, *)
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, canFocusRowAtIndexPath indexPath: NSIndexPath) -> Bool? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, canFocusRowAtIndexPath: indexPath)
    }
    
    @available(iOS 9.0, *)
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, shouldUpdateFocusInContext context: UITableViewFocusUpdateContext) -> Bool? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, shouldUpdateFocusInContext: context)
    }
    
    @available(iOS 9.0, *)
    func tableViewController(viewController: MJTableViewController, tableView: UITableView, didUpdateFocusInContext context: UITableViewFocusUpdateContext, withAnimationCoordinator coordinator: UIFocusAnimationCoordinator) {
        if viewController != selectedViewController { return }
        delegate?.mjViewController?(self, selectedIndex: selectedIndex, tableView: tableView, didUpdateFocusInContext: context, withAnimationCoordinator: coordinator)
    }
    
    @available(iOS 9.0, *)
    func tableViewController(viewController: MJTableViewController, indexPathForPreferredFocusedViewInTableView tableView: UITableView) -> NSIndexPath? {
        if viewController != selectedViewController { return nil }
        return delegate?.mjViewController?(self, selectedIndex: viewControllers.indexOf(viewController)!, indexPathForPreferredFocusedViewInTableView: tableView)
    }
}

//MARK: - MJContentViewDelegate
extension MJViewController: MJContentViewDelegate {
    func contentView(contentView: MJContentView, didChangeValueOfSegmentedControl segmentedControl: UISegmentedControl) {
        addContentViewToEscapeView()
        UIView.animateWithDuration(0.25, animations: {
            self.scrollView.setContentOffset(CGPoint(x: self.scrollView.bounds.size.width * CGFloat(segmentedControl.selectedSegmentIndex), y: 0), animated: false)
        }) { finished in
            self.addContentViewToCell()
        }
    }
}