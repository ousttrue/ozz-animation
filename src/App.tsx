import './App.css'
import { category, type ArticleType } from './data';
import png from '../media/icon/ozz-grey-128.png';

function Article(props: ArticleType) {
  return (<div>
    <a href={props.url} target="_blank">
      {props.title}
    </a>
  </div>)
}

function App() {
  return (
    <>
      <img src={png} />
      {category.articles.map((props, i) => <Article key={i} {...props} />)}
    </>
  )
}

export default App
