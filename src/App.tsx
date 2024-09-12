import './App.css'
import { category, type ArticleType } from './data';
import png from '../media/icon/ozz-grey-128.png';

function Article(props: ArticleType) {
  return (<div className="item">
    <a href={props.url} target="_blank">
      {props.title}
    </a>
    <a href={`/ozz-animation/wasm/${props.title}.html`}>
      <figure>
        <img width={300} height={157} src={`/ozz-animation/wasm/${props.title}.jpg`}/>
      </figure>
    </a>
  </div>)
}

function App() {
  return (
    <>
      <header>
        <nav><a href="https://github.com/ousttrue/ozz-animation">git</a></nav>
      </header>
      <img src={png} />
      <div>
        draw by <a href="https://github.com/floooh/sokol-zig">sokol-zig</a>
      </div>
      <main className="container">
        {category.articles.map((props, i) => <Article key={i} {...props} />)}
      </main>
    </>
  )
}

export default App
