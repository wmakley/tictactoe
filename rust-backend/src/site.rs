use axum::{
    body::{boxed, Body, BoxBody},
    http::{Request, Response, StatusCode, Uri},
};
use tower::util::ServiceExt;
use tower_http::services::ServeDir;
use tracing::debug;

pub async fn index(_: Uri) -> Result<Response<BoxBody>, (StatusCode, String)> {
    // println!("root uri: {:?}", uri);
    let mut r = get_static_file("/index.html".parse().unwrap()).await?;

    r.headers_mut().insert(
        "cache-control",
        "no-cache; no-store; must-revalidate".parse().unwrap(),
    );
    Ok(r)
    // Set no cache headers
    // Ok(Response::builder()
    //     .status(r.status())
    //     .header("content-type", "text/html")
    //     .header("cache-control", "no-cache; no-store; must-revalidate")
    //     .body(boxed(r.into_body()))
    //     .unwrap())
}

pub async fn static_file_server(uri: Uri) -> Result<Response<BoxBody>, (StatusCode, String)> {
    // println!("file_handler uri: {:?}", uri);
    let res = get_static_file(uri.clone()).await?;
    // println!("{:?}", res);

    // allows retry with `.html` extension if desired (it isn't)
    if res.status() == StatusCode::NOT_FOUND {
        debug!("File Not Found: {:?}", uri);
        // println!("File Server 404: {:?}", uri);
        Err((StatusCode::NOT_FOUND, "Not Found".to_string()))
        // try with `.html`
        // TODO: handle if the Uri has query parameters
        // match format!("{}.html", uri).parse() {
        //     Ok(uri_html) => get_static_file(uri_html).await,
        //     Err(_) => Err((StatusCode::INTERNAL_SERVER_ERROR, "Invalid URI".to_string())),
        // }
    } else if uri.path().ends_with(".html") {
        // println!("File Server 301: {:?}", uri);
        // prevent caching of html files
        let mut res = res;
        res.headers_mut().insert(
            "cache-control",
            "no-cache; no-store; must-revalidate".parse().unwrap(),
        );
        Ok(res)
    } else {
        // println!("File Server 200: {:?}", uri);
        Ok(res)
    }
}

async fn get_static_file(uri: Uri) -> Result<Response<BoxBody>, (StatusCode, String)> {
    // println!("get_static_file uri: {:?}", uri);
    let req = Request::builder().uri(uri).body(Body::empty()).unwrap();

    // `ServeDir` implements `tower::Service` so we can call it with `tower::ServiceExt::oneshot`
    // When run normally, the root is the workspace root
    match ServeDir::new("./static").oneshot(req).await {
        Ok(res) => Ok(res.map(boxed)),
        Err(err) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("Something went wrong: {}", err),
        )),
    }
}
