-- Database Migration for AI Agent
-- Run this to add scoring columns and tables

-- Add AI score columns to blog_posts table
ALTER TABLE blog_posts
ADD COLUMN IF NOT EXISTS ai_score INTEGER DEFAULT NULL,
ADD COLUMN IF NOT EXISTS last_scored_at TIMESTAMP DEFAULT NULL;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_blog_posts_ai_score ON blog_posts(ai_score DESC);

-- Create post_analysis table for detailed scoring
CREATE TABLE IF NOT EXISTS post_analysis (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES blog_posts(id) ON DELETE CASCADE,
    technical_accuracy_score INTEGER NOT NULL,
    clarity_score INTEGER NOT NULL,
    completeness_score INTEGER NOT NULL,
    code_quality_score INTEGER NOT NULL,
    seo_score INTEGER NOT NULL,
    engagement_score INTEGER NOT NULL,
    total_score INTEGER NOT NULL,
    suggestions JSONB,
    analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    model_version VARCHAR(50),
    CONSTRAINT chk_technical_accuracy CHECK (technical_accuracy_score >= 0 AND technical_accuracy_score <= 25),
    CONSTRAINT chk_clarity CHECK (clarity_score >= 0 AND clarity_score <= 20),
    CONSTRAINT chk_completeness CHECK (completeness_score >= 0 AND completeness_score <= 20),
    CONSTRAINT chk_code_quality CHECK (code_quality_score >= 0 AND code_quality_score <= 15),
    CONSTRAINT chk_seo CHECK (seo_score >= 0 AND seo_score <= 10),
    CONSTRAINT chk_engagement CHECK (engagement_score >= 0 AND engagement_score <= 10),
    CONSTRAINT chk_total CHECK (total_score >= 0 AND total_score <= 100)
);

-- Create indexes for post_analysis table
CREATE INDEX IF NOT EXISTS idx_post_analysis_post_id ON post_analysis(post_id);
CREATE INDEX IF NOT EXISTS idx_post_analysis_analyzed_at ON post_analysis(analyzed_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_analysis_total_score ON post_analysis(total_score DESC);

-- Create view for latest scores
CREATE OR REPLACE VIEW latest_post_scores AS
SELECT DISTINCT ON (bp.id)
    bp.id,
    bp.title,
    bp.category,
    bp.author,
    bp.created_at,
    bp.ai_score,
    bp.last_scored_at,
    pa.technical_accuracy_score,
    pa.clarity_score,
    pa.completeness_score,
    pa.code_quality_score,
    pa.seo_score,
    pa.engagement_score,
    pa.total_score,
    pa.suggestions,
    pa.model_version,
    pa.analyzed_at
FROM blog_posts bp
LEFT JOIN post_analysis pa ON bp.id = pa.post_id
WHERE bp.ai_score IS NOT NULL
ORDER BY bp.id, pa.analyzed_at DESC;

COMMENT ON TABLE post_analysis IS 'Stores detailed AI scoring analysis for blog posts';
COMMENT ON COLUMN blog_posts.ai_score IS 'Latest AI quality score (0-100)';
COMMENT ON COLUMN blog_posts.last_scored_at IS 'Timestamp of last AI scoring';
