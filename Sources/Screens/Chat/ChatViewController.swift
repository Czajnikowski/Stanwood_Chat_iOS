//
//  ChatViewController.swift
//  Chat
//
//  Created by Maciek on 18.01.2018.
//  Copyright © 2018 Stanwood. All rights reserved.
//

import UIKit

internal protocol InternalChatViewControllerDataSource: class {
    var penultimateMessageIndex: Int? { get }
    var shouldReloadPenultimateMessage: Bool { get }
    
    func numberOfMessages() -> Int
    func messageCellViewModel(at index: Int) -> MessageCellViewModel
}

public protocol ChatViewControllerDelegate: class {
    func didReceive(_ message: String)
}

internal protocol InternalChatViewControllerDelegate: ChatViewControllerDelegate {
    func didReply(with message: String)
}

public class ChatViewController: UIViewController {
    static func loadFromStoryboard() -> ChatViewController {
        return UIStoryboard(name: "Chat", bundle: Bundle(for: ChatViewController.self))
            .instantiateInitialViewController() as! ChatViewController
    }
    
    @IBOutlet private weak var bottomLayoutConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var textView: UITextView!
    
    var dataSource: InternalChatViewControllerDataSource?
    var delegate: InternalChatViewControllerDelegate?
    
    private var keyboardHandler: KeyboardHandler!
    private var keepingAtTheBottomOffsetCalculator: KeepingAtTheBottomOffsetCalculator!
    
    private var tableViewBottomOffset: CGFloat {
        return view.frame.size.height - tableView.frame.size.height
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        keyboardHandler = KeyboardHandler(
            withBottomConstraint: bottomLayoutConstraint,
            andAnimations: { [unowned self] in
                self.view.layoutIfNeeded()
                self.tableView.contentOffset = self.keepingAtTheBottomOffsetCalculator.calculate()
            }
        )
        
        keepingAtTheBottomOffsetCalculator = KeepingAtTheBottomOffsetCalculator(for: tableView)
    }
    
    public func reply(with message: String) {
        delegate?.didReply(with: message)
        
        insertNewRow()
        scrollToTheBottom()
    }
    
    private func send(_ message: String) {
        delegate?.didReceive(message)
        
        reloadPenultimateRowIfNeeded()
        insertNewRow()
        scrollToTheBottom()
        
        textView.text = nil
    }
    
    private func reloadPenultimateRowIfNeeded() {
        guard let dataSource = dataSource else { return }
        guard dataSource.shouldReloadPenultimateMessage else { return }
        
        if let penultimateMessageIndex = dataSource.penultimateMessageIndex {
            DispatchQueue.main.async { [unowned self] in
                self.tableView.reloadRows(
                    at: [IndexPath(row: penultimateMessageIndex, section: 0)],
                    with: UITableViewRowAnimation.fade
                )
            }
            
        }
    }
    
    private func insertNewRow() {
        guard let dataSource = dataSource else { return }
        
        tableView.beginUpdates()
        tableView.insertRows(
            at: [IndexPath(row: dataSource.numberOfMessages() - 1, section: 0)],
            with: .fade
        )
        tableView.endUpdates()
    }
    
    private func scrollToTheBottom() {
        guard let dataSource = dataSource else { return }
        guard dataSource.numberOfMessages() > 0 else { return }
        
        DispatchQueue.main.async { [unowned self] in
            self.tableView.scrollToRow(
                at: IndexPath(row: dataSource.numberOfMessages() - 1, section: 0),
                at: UITableViewScrollPosition.bottom,
                animated: true
            )
        }
    }
}

extension ChatViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource?.numberOfMessages() ?? 0
    }
    
    public func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell {
        
        let cell = tableView.dequeue(cellType: MessageCell.self, for: indexPath)
        
        guard let dataSource = dataSource else { return cell }
        
        cell.prepare(with: dataSource.messageCellViewModel(at: indexPath.row))
        
        return cell
    }
}

extension ChatViewController: UITextViewDelegate {
    public func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
        ) -> Bool {
        
        if text == "\n" {
            guard let message = textView.text, message != "" else { return false }
            
            send(message)
            
            return false
        }
        
        return true
    }
}

extension ChatViewController: UIStackViewDelegate {
    func didLayoutSubViews() {
        DispatchQueue.main.async { [unowned self] in
            self.tableView.contentOffset = self.keepingAtTheBottomOffsetCalculator.calculate()
        }
    }
}
