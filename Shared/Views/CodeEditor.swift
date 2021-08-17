//
//  CodeEditor.swift
//  Signed
//
//  Created by Markus Moenig on 25/8/20.
//

import SwiftUI
import WebKit
import Combine

class CodeEditor
{
    var webView         : WKWebView
    var model           : Model
    var colorScheme     : ColorScheme
    
    var sessions        : [String] = []
    
    var currentSession  : String
    
    init(_ view: WKWebView, _ model: Model,_ colorScheme: ColorScheme)
    {
        self.webView = view
        self.model = model
        self.colorScheme = colorScheme

        currentSession = "__project"
        createSession(value: model.project.code)
        setTheme(colorScheme)
    }
    
    /// Create a new editor session
    func createSession(value: String, session: String = "__project", cb: (()->())? = nil)
    {
        sessions.append(session)
        currentSession = session

        webView.evaluateJavaScript(
            """
            var \(session) = ace.createEditSession(`\(value)`)
            editor.setSession(\(session))
            editor.session.setMode("ace/mode/lua");
            """, completionHandler: { (value, error ) in
                if let cb = cb {
                    cb()
                }
         })
    }
    
    /// Set the theme
    func setTheme(_ colorScheme: ColorScheme)
    {
        let theme: String
        if colorScheme == .light {
            theme = "tomorrow"
        } else {
            theme = "tomorrow_night"//_bright"
        }
        webView.evaluateJavaScript(
            """
            editor.setTheme("ace/theme/\(theme)");
            """, completionHandler: { (value, error ) in
         })
    }
    
    /// Make editor read only
    func setReadOnly(_ readOnly: Bool = false)
    {
        webView.evaluateJavaScript(
            """
            editor.setReadOnly(\(readOnly));
            """, completionHandler: { (value, error) in
         })
    }
    
    /// Silent mode
    func setSilentMode(_ silent: Bool = false)
    {
        webView.evaluateJavaScript(
            """
            editor.setOptions({
                cursorStyle: \(silent ? "'wide'" : "'ace'") // "ace"|"slim"|"smooth"|"wide"
            });
            """, completionHandler: { (value, error) in
         })
    }
    
    /// Get the current value from the session
    func getValue(session: String = "__project", cb: @escaping (String)->() )
    {
        webView.evaluateJavaScript(
            """
            \(session).getValue();
            """, completionHandler: { (value, error) in
                if let value = value as? String {
                    cb(value)
                }
         })
    }
    
    /// Set the value for the given session context
    func setSession(value: String, session: String = "__project")
    {
        if sessions.contains(session) == false {
            createSession(value: value, session: session)
            return
        }
        
        let cmd = """
        editor.setSession(\(session))
        editor.clearSelection();
        """
        webView.evaluateJavaScript(cmd, completionHandler: { (value, error ) in
            self.currentSession = session
        })
    }
    
    /// Goto a given line and column
    func gotoLine(_ line: Int32,_ column: Int32 = 0)
    {
        webView.evaluateJavaScript(
            """
            editor.getCursorPosition().row
            editor.scrollToLine(\(line), true, true, function () {});
            editor.gotoLine(\(line), \(column), true);
            """, completionHandler: { (value, error ) in
         })
    }
    
    /// Get the current cursor position
    func getSessionCursor(_ cb: @escaping (Int32, Int32)->() )
    {
        webView.evaluateJavaScript(
            """
            editor.getCursorPosition()
            """, completionHandler: { (value, error ) in
                if let map = value as? [String:Any] {
                    var row      : Int32 = -1
                    var column   : Int32 = -1
                    if let r = map["row"] as? Int32 {
                        row = r
                    }
                    if let c = map["column"] as? Int32 {
                        column = c
                    }

                    cb(row, column)
                }
         })
    }
    
    /// Get the current change delta
    func getChangeDelta(_ cb: @escaping (Int32, Int32)->() )
    {
        webView.evaluateJavaScript(
            """
            delta
            """, completionHandler: { (value, error ) in
                if let map = value as? [String:Any] {
                    var from : Int32 = -1
                    var to   : Int32 = -1
                    if let f = map["start"] as? [String:Any] {
                        if let ff = f["row"] as? Int32 {
                            from = ff
                        }
                    }
                    if let t = map["end"] as? [String:Any] {
                        if let tt = t["row"] as? Int32 {
                            to = tt
                        }
                    }
                    cb(from, to)
                }
         })
    }
    
    /// Clear annotations
    func clearAnnotations()
    {
        webView.evaluateJavaScript(
            """
            editor.getSession().clearAnnotations()
            """, completionHandler: { (value, error ) in
         })
    }
    
    /// Set errors and warnings
    func setErrors(_ errors: [CodeError])
    {
        var str = "["
        for error in errors {
            str +=
            """
            {
                row: \(error.line),
                column: \(error.column),
                text: \"\(error.error!)\",
                type: \"\(error.type)\"
            },
            """
        }
        str += "]"
        
        webView.evaluateJavaScript(
            """
            editor.getSession().setAnnotations(\(str));
            """, completionHandler: { (value, error ) in
         })
    }
    
    /// The code was updated in the editor
    func updated()
    {
        print("yy", currentSession)
        getValue(session: currentSession, cb: { (value) in
            if self.currentSession == "__project" {
                self.model.project.code = value
            } else {
                let managedObjectContext = PersistenceController.shared.container.viewContext

                if self.model.codeEditorMode == .module {
                    if let module = self.model.codeEditorModuleEntity {
                        print("updating", value)
                        module.code = value.data(using: .utf8)
                    }
                }
                
                do {
                    try managedObjectContext.save()
                } catch {}
            }
        })
    }
}

class WebViewModel: ObservableObject {
    @Published var didFinishLoading: Bool = false
    
    init () {
    }
}

#if os(OSX)
struct SwiftUIWebView: NSViewRepresentable {
    public typealias NSViewType = WKWebView
    var model       : Model!
    var colorScheme : ColorScheme

    private let webView: WKWebView = WKWebView()
    public func makeNSView(context: NSViewRepresentableContext<SwiftUIWebView>) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator as? WKUIDelegate
        webView.configuration.userContentController.add(context.coordinator, name: "jsHandler")
        
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Files") {
            webView.isHidden = true
            webView.loadFileURL(url, allowingReadAccessTo: url)
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<SwiftUIWebView>) { }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(model, colorScheme)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        
        private var model        : Model
        private var colorScheme : ColorScheme

        init(_ model: Model,_ colorScheme: ColorScheme) {
            self.model = model
            self.colorScheme = colorScheme
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "jsHandler" {
                if let codeEditor = model.codeEditor {
                    codeEditor.updated()
                }
            }
        }
        
        public func webView(_: WKWebView, didFail: WKNavigation!, withError: Error) { }

        public func webView(_: WKWebView, didFailProvisionalNavigation: WKNavigation!, withError: Error) { }

        //After the webpage is loaded, assign the data in WebViewModel class
        public func webView(_ web: WKWebView, didFinish: WKNavigation!) {
            model.codeEditor = CodeEditor(web, model, colorScheme)
            web.isHidden = false
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { }

        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
#else
struct SwiftUIWebView: UIViewRepresentable {
    public typealias UIViewType = WKWebView
    var model       : Model!
    var colorScheme : ColorScheme
    
    private let webView: WKWebView = WKWebView()
    public func makeUIView(context: UIViewRepresentableContext<SwiftUIWebView>) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator as? WKUIDelegate
        webView.configuration.userContentController.add(context.coordinator, name: "jsHandler")
        
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Files") {
            
            webView.loadFileURL(url, allowingReadAccessTo: url)
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<SwiftUIWebView>) { }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(model, colorScheme)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        
        private var model        : Model
        private var colorScheme : ColorScheme
        
        init(_ model: Model,_ colorScheme: ColorScheme) {
            self.model = model
            self.colorScheme = colorScheme
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "jsHandler" {
                if let scriptEditor = model.codeEditor {
                    scriptEditor.updated()
                }
            }
        }
        
        public func webView(_: WKWebView, didFail: WKNavigation!, withError: Error) { }

        public func webView(_: WKWebView, didFailProvisionalNavigation: WKNavigation!, withError: Error) { }

        //After the webpage is loaded, assign the data in WebViewModel class
        public func webView(_ web: WKWebView, didFinish: WKNavigation!) {
            model.codeEditor = CodeEditor(web, model, colorScheme)
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { }

        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

    }
}

#endif

struct WebView  : View {
    var model       : Model
    var colorScheme : ColorScheme

    init(_ model: Model,_ colorScheme: ColorScheme) {
        self.model = model
        self.colorScheme = colorScheme
    }
    
    var body: some View {
        SwiftUIWebView(model: model, colorScheme: colorScheme)
    }
}
