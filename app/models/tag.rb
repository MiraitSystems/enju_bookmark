class Tag < ActiveRecord::Base
  attr_accessible :name, :name_transcription
  has_many :taggings, :dependent => :destroy, :class_name => 'ActsAsTaggableOn::Tagging'
  validates :name, :presence => true
  validate :contain_space
  after_save :save_taggings, :tag_delete
  after_destroy :save_taggings

  extend FriendlyId
  friendly_id :name

  searchable do
    text :name
    string :name
    time :created_at
    time :updated_at
    integer :bookmark_ids, :multiple => true do
      tagged(Bookmark).compact.collect(&:id)
    end
    integer :taggings_count do
      taggings.size
    end
  end

  paginates_per 10

  def self.bookmarked(bookmark_ids, options = {})
    count = Tag.count
    count = Tag.default_per_page if count == 0
    unless bookmark_ids.empty?
      tags = Tag.search do
        with(:bookmark_ids).any_of bookmark_ids
        order_by :taggings_count, :desc
        paginate(:page => 1, :per_page => count)
      end.results
    end
  end

  def save_taggings
    self.taggings.collect(&:taggable).each do |t| t.save end
  end

  def tagged(taggable_type)
    self.taggings.where(:taggable_type => taggable_type.to_s).includes(:taggable).collect(&:taggable)
  end

  def contain_space
    if self.name =~ /\s/ or name.index(I18n.t('tag.space'))
      errors.add(:name, I18n.t('tag.contain_space'))
    end
  end

  def tag_delete
    tags = Tag.find(:all)
    tags.each{ |tag| Tag.delete(tag) if tag.taggings.size == 0 }
  end
end

# == Schema Information
#
# Table name: tags
#
#  id                 :integer          not null, primary key
#  name               :string(255)
#  name_transcription :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

