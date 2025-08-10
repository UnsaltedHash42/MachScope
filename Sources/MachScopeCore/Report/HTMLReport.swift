import Foundation

public struct HTMLReport {
    public init() {}
    public func render(records: [Record]) -> String {
        let rows = records.map { r -> String in
            let findings = r.findings.map { f in
                "<span class=\"badge \(f.severity.rawValue)\">\(f.id)</span>"
            }.joined(separator: " ")
            let hardened = r.hardenedRuntime == true ? "Yes" : "No"
            return "<tr><td>\(escape(r.path))</td><td>\(escape(r.bundleId ?? ""))</td><td>\(escape(r.teamId ?? ""))</td><td>\(hardened)</td><td>\(r.arch.joined(separator: ","))</td><td>\(escape(r.notarization ?? ""))</td><td>\(findings)</td></tr>"
        }.joined(separator: "\n")

        let html = """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8" />
        <title>MachScope Report</title>
        <style>
        body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:16px}
        h1{margin:0 0 12px 0}
        .meta{color:#555;margin-bottom:12px}
        table{border-collapse:collapse;width:100%}
        th,td{border:1px solid #ddd;padding:8px;font-size:14px}
        th{background:#f6f8fa;cursor:pointer;text-align:left}
        tr:nth-child(even){background:#fafafa}
        .badge{padding:2px 6px;border-radius:4px;font-size:12px;color:#fff}
        .badge.low{background:#6a737d}
        .badge.medium{background:#d97706}
        .badge.high{background:#dc2626}
        .badge.critical{background:#7f1d1d}
        </style>
        </head>
        <body>
        <h1>MachScope Report</h1>
        <div class=\"meta\">Total records: \(records.count)</div>
        <table id=\"report\">
          <thead>
            <tr>
              <th onclick=\"sortTable(0)\">Path</th>
              <th onclick=\"sortTable(1)\">Bundle ID</th>
              <th onclick=\"sortTable(2)\">Team ID</th>
              <th onclick=\"sortTable(3)\">Hardened</th>
              <th onclick=\"sortTable(4)\">Arch</th>
              <th onclick=\"sortTable(5)\">Notarization</th>
              <th>Findings</th>
            </tr>
          </thead>
          <tbody>
          \(rows)
          </tbody>
        </table>
        <script>
        function sortTable(n){
          const table=document.getElementById('report');
          const tbody=table.tBodies[0];
          const rows=Array.from(tbody.rows);
          const asc=table.getAttribute('data-sort')!=='col'+n+':asc';
          rows.sort((a,b)=>{
            const A=a.cells[n].innerText.toLowerCase();
            const B=b.cells[n].innerText.toLowerCase();
            if(A<B) return asc?-1:1; if(A>B) return asc?1:-1; return 0;
          });
          rows.forEach(r=>tbody.appendChild(r));
          table.setAttribute('data-sort','col'+n+(asc?':asc':':desc'));
        }
        </script>
        </body>
        </html>
        """
        return html
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
