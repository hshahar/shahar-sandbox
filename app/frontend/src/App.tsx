import { useState, useEffect } from 'react'
import axios from 'axios'
import './App.css'

interface BlogPost {
  id: number
  title: string
  content: string
  category: string
  author: string
  tags: string | null
  created_at: string
  updated_at: string
  ai_score?: number | null
  last_scored_at?: string | null
}

interface BlogPostForm {
  title: string
  content: string
  category: string
  author: string
  tags: string
}

const categories = [
  'Kubernetes Features',
  'Security Best Practices',
  'CI/CD Workflows',
  'Helm and Package Management',
  'Networking',
  'Storage',
  'Monitoring and Observability',
  'GitOps'
]

function App() {
  const [posts, setPosts] = useState<BlogPost[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showForm, setShowForm] = useState(false)
  const [editingPost, setEditingPost] = useState<BlogPost | null>(null)
  const [selectedPost, setSelectedPost] = useState<BlogPost | null>(null)
  const [formData, setFormData] = useState<BlogPostForm>({
    title: '',
    content: '',
    category: categories[0],
    author: 'SHA',
    tags: ''
  })

  useEffect(() => {
    fetchPosts()
  }, [])

  const fetchPosts = async () => {
    try {
      const response = await axios.get('/api/posts')
      setPosts(response.data)
      setLoading(false)
    } catch (err) {
      setError('Failed to fetch blog posts')
      setLoading(false)
    }
  }

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    })
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    try {
      if (editingPost) {
        await axios.put(`/api/posts/${editingPost.id}`, formData)
      } else {
        await axios.post('/api/posts', formData)
      }
      setShowForm(false)
      setEditingPost(null)
      setFormData({
        title: '',
        content: '',
        category: categories[0],
        author: 'SHA',
        tags: ''
      })
      fetchPosts()
    } catch (err) {
      alert('Failed to save post')
    }
  }

  const handleEdit = (post: BlogPost) => {
    setEditingPost(post)
    setFormData({
      title: post.title,
      content: post.content,
      category: post.category,
      author: post.author,
      tags: post.tags || ''
    })
    setShowForm(true)
    setSelectedPost(null)
  }

  const handleDelete = async (id: number) => {
    if (window.confirm('Are you sure you want to delete this post?')) {
      try {
        await axios.delete(`/api/posts/${id}`)
        fetchPosts()
        setSelectedPost(null)
      } catch (err) {
        alert('Failed to delete post')
      }
    }
  }

  const handleNewPost = () => {
    setShowForm(true)
    setEditingPost(null)
    setSelectedPost(null)
    setFormData({
      title: '',
      content: '',
      category: categories[0],
      author: 'SHA',
      tags: ''
    })
  }

  const handleCancel = () => {
    setShowForm(false)
    setEditingPost(null)
    setFormData({
      title: '',
      content: '',
      category: categories[0],
      author: 'SHA',
      tags: ''
    })
  }

  if (loading) {
    return (
      <div className="container">
        <div className="loading">Loading posts...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="container">
        <div className="error">{error}</div>
      </div>
    )
  }

  // Helper function to get AI score badge
  const getScoreBadge = (score: number | null | undefined) => {
    if (!score) return null

    let badgeClass = 'score-badge '
    let emoji = ''

    if (score >= 90) {
      badgeClass += 'score-excellent'
      emoji = '⭐'
    } else if (score >= 80) {
      badgeClass += 'score-good'
      emoji = '✨'
    } else if (score >= 70) {
      badgeClass += 'score-average'
      emoji = '👍'
    } else if (score >= 60) {
      badgeClass += 'score-fair'
      emoji = '📝'
    } else {
      badgeClass += 'score-poor'
      emoji = '💡'
    }

    return (
      <div className={badgeClass} title="AI Quality Score">
        {emoji} {score}/100
      </div>
    )
  }

  return (
    <div className="app">
      <header className="header">
        <div className="container">
          <h1>☸️ SHA's Kubernetes Blog Platform</h1>
          <p className="subtitle">
            Latest insights on Kubernetes, Security, CI/CD, and DevOps
          </p>
          <button className="btn btn-primary" onClick={handleNewPost}>
            ✏️ Write New Post
          </button>
        </div>
      </header>

      <main className="container">
        {showForm && (
          <div className="modal">
            <div className="modal-content">
              <h2>{editingPost ? 'Edit Post' : 'Create New Post'}</h2>
              <form onSubmit={handleSubmit}>
                <div className="form-group">
                  <label>Title *</label>
                  <input
                    type="text"
                    name="title"
                    value={formData.title}
                    onChange={handleInputChange}
                    required
                    placeholder="Enter post title..."
                  />
                </div>

                <div className="form-group">
                  <label>Category *</label>
                  <select
                    name="category"
                    value={formData.category}
                    onChange={handleInputChange}
                    required
                  >
                    {categories.map((cat) => (
                      <option key={cat} value={cat}>
                        {cat}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label>Content *</label>
                  <textarea
                    name="content"
                    value={formData.content}
                    onChange={handleInputChange}
                    required
                    rows={10}
                    placeholder="Write your blog post content..."
                  />
                </div>

                <div className="form-group">
                  <label>Tags (comma-separated)</label>
                  <input
                    type="text"
                    name="tags"
                    value={formData.tags}
                    onChange={handleInputChange}
                    placeholder="kubernetes, docker, ci/cd"
                  />
                </div>

                <div className="form-group">
                  <label>Author *</label>
                  <input
                    type="text"
                    name="author"
                    value={formData.author}
                    onChange={handleInputChange}
                    required
                  />
                </div>

                <div className="form-actions">
                  <button type="submit" className="btn btn-primary">
                    {editingPost ? 'Update Post' : 'Create Post'}
                  </button>
                  <button type="button" className="btn btn-secondary" onClick={handleCancel}>
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {selectedPost && (
          <div className="modal" onClick={() => setSelectedPost(null)}>
            <div className="modal-content post-detail" onClick={(e) => e.stopPropagation()}>
              <div className="post-detail-header">
                <div>
                  <div className="post-category">{selectedPost.category}</div>
                  <h2>{selectedPost.title}</h2>
                  <div className="post-meta">
                    <span>By {selectedPost.author}</span>
                    <span>•</span>
                    <span>{new Date(selectedPost.created_at).toLocaleDateString()}</span>
                  </div>
                </div>
                <button className="btn-close" onClick={() => setSelectedPost(null)}>✕</button>
              </div>
              <div className="post-content">
                {selectedPost.content}
              </div>
              {selectedPost.tags && (
                <div className="post-tags">
                  {selectedPost.tags.split(',').map((tag, idx) => (
                    <span key={idx} className="tag">{tag.trim()}</span>
                  ))}
                </div>
              )}
              <div className="post-actions">
                <button className="btn btn-warning" onClick={() => handleEdit(selectedPost)}>
                  ✏️ Edit
                </button>
                <button className="btn btn-danger" onClick={() => handleDelete(selectedPost.id)}>
                  🗑️ Delete
                </button>
              </div>
            </div>
          </div>
        )}

        <div className="posts-grid">
          {posts.length === 0 ? (
            <div className="empty-state">
              <h2>No posts yet</h2>
              <p>Start by creating your first blog post about Kubernetes!</p>
              <button className="btn btn-primary" onClick={handleNewPost}>
                ✏️ Create First Post
              </button>
            </div>
          ) : (
            posts.map((post) => (
              <article key={post.id} className="post-card" onClick={() => setSelectedPost(post)}>
                <div className="post-category">{post.category}</div>
                {getScoreBadge(post.ai_score)}
                <h2 className="post-title">{post.title}</h2>
                <div className="post-meta">
                  <span>By {post.author}</span>
                  <span>•</span>
                  <span>{new Date(post.created_at).toLocaleDateString()}</span>
                  {post.ai_score === null && post.last_scored_at === null && (
                    <>
                      <span>•</span>
                      <span className="scoring-status">🤖 Scoring...</span>
                    </>
                  )}
                </div>
                <p className="post-excerpt">
                  {post.content.substring(0, 150)}...
                </p>
                {post.tags && (
                  <div className="post-tags">
                    {post.tags.split(',').map((tag, idx) => (
                      <span key={idx} className="tag">
                        {tag.trim()}
                      </span>
                    ))}
                  </div>
                )}
                <div className="card-actions">
                  <button
                    className="btn btn-sm btn-warning"
                    onClick={(e) => { e.stopPropagation(); handleEdit(post); }}
                  >
                    ✏️ Edit
                  </button>
                  <button
                    className="btn btn-sm btn-danger"
                    onClick={(e) => { e.stopPropagation(); handleDelete(post.id); }}
                  >
                    🗑️ Delete
                  </button>
                </div>
              </article>
            ))
          )}
        </div>
      </main>

      <footer className="footer">
        <div className="container">
          <p>
            Built with ❤️ using ArgoCD, Helm, and Kubernetes | GitOps-powered deployment | {posts.length} posts
          </p>
          <div className="service-links">
            <h3>📊 Platform Services</h3>
            <div className="links-grid">
              <a href="http://k8s-logging-kibana-f737ecb493-640190764.us-west-2.elb.amazonaws.com" target="_blank" rel="noopener noreferrer" className="service-link">
                🔍 Kibana
              </a>
              <a href="/ai/" target="_blank" rel="noopener noreferrer" className="service-link">
                🤖 AI Agent
              </a>
              <span className="service-link service-link-disabled" title="Grafana available via port-forward: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80">
                📈 Grafana (Internal)
              </span>
              <span className="service-link service-link-disabled" title="ArgoCD available via port-forward: kubectl port-forward -n argocd svc/argocd-server 8080:443">
                🚀 ArgoCD (Internal)
              </span>
              <span className="service-link service-link-disabled" title="Vault available via port-forward: kubectl port-forward -n vault svc/vault 8200:8200">
                🔐 Vault (Internal)
              </span>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}

export default App
